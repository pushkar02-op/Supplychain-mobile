# Deployment Pipeline Design & Validation RFC

**Date:** 2025-12-21
**Status:** PROPOSED
**Scope:** CI/CD, Production Deployment, Operational Workflows

---

## 1. Executive Summary

**Problem:** The current production deployment (`ec2-deploy.yml`) performs a raw `docker run` which relies on the Dockerfile's default CMD (`uvicorn`). It **skips database migrations**, creating a dangerous divergence from local dev (which runs migrations via Compose). Additionally, CI tests run on the host system, failing to catch container-specific issues.

**Solution:** Transition to a **Container-First** pipeline where:
1.  **Build Once:** The Docker image is the single source of truth.
2.  **Explicit release Phase:** Migrations run in a dedicated, ephemeral container instance *before* the app starts.
3.  **Containerized CI:** Tests run *inside* the built image.

---

## 2. Target Deployment Flow (End-to-End)

### A. Pull Request (CI Check)
*Goal: Validate that the artifact we WILL build allows tests to pass.*

1.  **Build:** `docker build -t app:test .`
2.  **Service:** Spin up `postgres:14` (detached).
3.  **Wait:** `wait-for-db.sh` using the app image.
4.  **Migrate:** `docker run --net host app:test alembic upgrade head`
    *   *Note: Using host networking in GitHub Actions shim simplifies connection to service container.*
5.  **Test:** `docker run --net host app:test pytest`

### B. Production Deployment (CD)
*Goal: deploy the exact image verified in CI, ensuring schema is up-to-date.*

1.  **Build & Push:** Build `app:latest` and push to Docker Hub.
2.  **SSH to EC2.**
3.  **Pull:** `docker pull app:latest`
4.  **Release (Migration) Phase:**
    ```bash
    # Run migrations in ephemeral container
    docker run --rm \
      --name supplychain-migrator \
      -e DATABASE_URL=... \
      app:latest \
      alembic upgrade head
    ```
    *   **Stop Condition:** If this fails, the deployment **ABORTS**. The old app version remains running.
5.  **Runtime Phase:**
    ```bash
    docker stop supplychain-app || true
    docker rm supplychain-app || true
    docker run -d --name supplychain-app -p 8000:8000 ... app:latest
    ```

---

## 3. Migration Strategy in Depth

**Decision:** Run migrations as a **Separate One-Off Container**.

*   **Why?**
    *   Decouples schema upgrades from app startup.
    *   Prevents concurrency races (e.g., if we scale to 2+ replicas, we don't want 2 containers trying to migrate DB simultaneously).
    *   Ensures boot speed is fast (app doesn't wait for alembic).

**Failure Handling:**
*   If `alembic upgrade head` fails (exit code != 0):
    *   The deployment script `exit 1`.
    *   The running `supplychain-app` container is **NOT** stopped.
    *   **Result:** Application stays on previous healthy version. No downtime.

**Zero-Downtime Consideration:**
*   Migrations MUST be backward compatible (e.g., add column, don't drop).
*   Code must handle both old and new schema during the rolling window (if we had load balancing, which we currently don't on single EC2).

---

## 4. Backfill & Ops Integration

**Standard Operator:**
Do not install Python/Venv on the DB node or Jumpbox. Use the image.

**Protocol:**
1.  **Local:** `docker compose exec backend python scripts/my_script.py`
2.  **Prod:**
    ```bash
    docker run --rm -it \
       -e DATABASE_URL=$PROD_URL \
       app:latest \
       python scripts/my_script.py
    ```

**CI Support:**
*   Scripts folder is included in the Docker image (`COPY app /app/app` logic might need adjustment if scripts are outside app, currently they are siblings. *Correction: Dockerfile copies `app`, scripts are logically outside. We need to ensure scripts are COPYed in Phase B.*).

---

## 5. Rollout & Rollback Safety

**Rollback Scenario:**
*   *Bad Code Deployment:* Re-run the GitHub Action for the *previous* commit. It pulls the old image and deploys.
*   *Bad Migration:*
    *   Requires manual `alembic downgrade`.
    *   **Action:** `docker run --rm ... app:latest alembic downgrade -1`
    *   **Risk:** Data written to new columns might be lost. (Standard DB risk).

**Verification:**
*   The deployment script logs the migration output.
*   Healthcheck `pg_isready` is insufficient. We rely on Alembic exit code.

---

## 6. Implementation Plan (Phased)

### Phase A: Safety First (No Downtime)
*Objective: Fix the immediate hole in Production where migrations don't run.*

1.  **Modify `ec2-deploy.yml`**:
    *   Insert the `Release Phase` (Migration step) before the `docker stop/run` block.
    *   Add error handling (`|| exit 1`).

### Phase B: Dockerfile Hardening
*Objective: Ensure scripts and tools are available.*

1.  **Update `Dockerfile`**:
    *   Ensure `scripts/` directory is copied into the image (currently likely missing if context is `backend/` and `scripts/` is root).
    *   *Correction from Repo Audit:* `scripts/` is at project root, `backend/` is sibling.
    *   **Action:** Move `scripts/` into `backend/scripts/` OR update Docker build context to be project root.
    *   *Recommended:* Move `scripts/` to `backend/scripts/` to keep Context clean.

### Phase C: CI Convergence
*Objective: CI matches Prod.*

1.  **Update `ci.yml`**:
    *   Remove host python setup.
    *   Use `docker build` + `docker run` pattern for tests.

---

## 7. Final Recommendation

**Immediate Action:** Execute **Phase A**.
Modifying `ec2-deploy.yml` is high-impact, low-effort, and fixes the critical correctness bug.
