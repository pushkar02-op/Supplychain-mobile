# Deployment Audit & Architecture RFC

**Date:** 2025-12-21
**Author:** Platform Engineering
**Status:** DRAFT (For Review)

---

## 1. Executive Summary

The current system suffers from **Environment Drift**. The way the application runs locally (Docker Compose) differs fundamentally from how it runs in CI (Host Process) and how it runs in Production (Raw Docker).

This drift causes operational friction:
- Scripts verified in CI fail locally.
- Scripts verified locally fail in Production.
- "It works on my machine" issues are frequent due to networking differences (`localhost` vs `db` vs RDS endpoint).

This document audits the current state and proposes a Unified container-first model.

---

## 2. Environment Truth Table

| Feature | **Local Development** | **CI (GitHub Actions)** | **Production (EC2)** |
| :--- | :--- | :--- | :--- |
| **Orchestration** | `docker-compose` | GitHub Actions Runner (Host) | Raw `docker run` (Shell Script) |
| **Database** | Container (`db`) | Service Container (`postgres`) | External (RDS or pre-provisioned) |
| **Network** | Docker Bridge (`db:5432`) | Localhost (`127.0.0.1:5432`) | Direct URL (Cloud Endpoint) |
| **Code Execution** | Application Container | Host Python Environment | Application Container |
| **Migrations** | Container Startup (`command`) | QA Step (Host) | **MISSING / Implicit** |
| **Hot Reload** | ✅ Yes (Volume Mount) | ❌ N/A | ❌ No |

---

## 3. Deployment Reality Audit

### A. Local Development ("The Docker Island")
- **Mechanism:** `docker-compose up`
- **Networking:** App talks to `db` hostname.
- **Friction:** You cannot run `python scripts/my_script.py` from your terminal because your terminal cannot resolve `db`. You MUST `docker compose exec backend ...`.

### B. CI Pipeline ("The Host Hybrid")
- **Mechanism:** Installs Python on the runner, spins up a sidecar Postgres.
- **Networking:** App talks to `localhost`.
- **Drift:** This verifies valid Python code, but **fails to verify the Docker image**. It does not test the entrypoint, the `wait-for-db` logic, or the actual production runtime environment.

### C. Production ("The Manual Docker Run")
- **Mechanism:** `ec2-deploy.yml` SSHs into EC2 and executes:
  ```bash
  docker run -d --name supplychain-app -p 8000:8000 -e DATABASE_URL=... image:latest
  ```
- **Major Risk:** There is no explicit "Run Migrations" step in the deploy pipeline.
    - *Implicit Reliance:* The `docker-compose.yml` has a `command` that runs migrations, BUT `docker run` uses the `Dockerfile` default CMD (`uvicorn` only), bypassing the migration command unless explicitly overridden!
    - **CRITICAL FINDING:** **Production might NOT be running migrations automatically**, or relies on a different entrypoint than local dev.
    - *Correction:* The `Dockerfile` has `wait-for-db.sh`, but the `CMD` is just `uvicorn`. The *migration command* is only present in `docker-compose.yml`.
    - **Verdict:** If Prod uses `docker run backend:latest` (as per `ec2-deploy.yml`), **MIGRATIONS ARE NOT RUNNING**.

---

## 4. Recommended Target Model (The "Container-First" Design)

To eliminate drift, **The Container is the Unit of Deployment**.

### Rule 1: CI Builds the Image, Tests Run IN the Image
CI should not `pip install`. CI should `docker build` and then `docker run pytest` inside that image. This guarantees that what you test is what you deploy.

### Rule 2: Explicit "Release Phase"
Migration is a distinct phase, not a startup side-effect.
- **Bad:** Container starts -> migrates -> runs app (Slow startup, concurrency issues if multiple replicas start).
- **Good:** CD Pipeline -> `docker run --rm backend alembic upgrade head` -> `docker run -d backend uvicorn`.

### Rule 3: Unified Script Execution
All ops tasks (backfills, fixing data) must be capable of running via `docker run --rm ...`.
- Input: `DATABASE_URL` env var.
- Output: Logs to stdout.

---

## 5. GitHub Actions Automation Plan

### Pipeline A: PR Checks (CI)
1. **Build** Docker Image (cached).
2. **Spin up** Compose Stack (App + Test DB).
3. **Run** `docker compose exec -T backend pytest`.
4. **Tear down**.

### Pipeline B: API Deployment (CD)
1. **Push** Image to Registry.
2. **SSH** to EC2.
3. **Pull** Image.
4. **Release Phase (Migration):**
   ```bash
   docker run --rm --env-file .env supplychain-app alembic upgrade head
   ```
5. **Rollout:**
   ```bash
   docker stop supplychain-app
   docker run -d ... supplychain-app
   ```

---

## 6. One-Off Ops Runbook (Revised)

**How to run a backfill (Local):**
```bash
docker compose exec backend python scripts/backfill_created_by.py
```

**How to run a backfill (Production):**
Do NOT SSH and run python manually.
```bash
# Production Ops Pattern
docker run --rm \
  -e DATABASE_URL=$PROD_DB_URL \
  my-registry/backend:latest \
  python scripts/backfill_created_by.py
```
*Why?* This ensures you use the exact code version and dependencies matching the deployed app.

---

## 7. Immediate Fixes Recommendations

1.  **Fix Production Entrypoint:**
    The `ec2-deploy.yml` currently runs `docker run ...` which defaults to `uvicorn`. It likely skips migrations.
    *Recommendation:* Update `ec2-deploy.yml` to explicitly run a migration container before starting the app container.

2.  **Harmonize CI:**
    Move CI from "Host Python" to "Docker Compose" based testing to catch Docker-specific issues (pathing, permissions, missing OS deps) earlier.

3.  **Document the `exec` Pattern:**
    Update README to explicitly state: "All/Any scripts must be run via `docker compose exec backend ...`".
