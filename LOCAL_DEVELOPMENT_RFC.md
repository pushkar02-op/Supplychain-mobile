# Local Development Standard & Protocol

**Date:** 2025-12-21
**Status:** APPROVED
**Usage:** Mandatory for all developers.

---

## 1. Executive Summary

To ensure **Production Parity** while maintaining **Developer Velocity**, we define a single canonical way to run the application locally.

**The Golden Rule:**
> "If it runs in `docker compose`, it runs in Production. If it runs on your host `venv`, it does not exist."

---

## 2. Canonical Local Run Model

### The Command
```powershell
docker compose up --build
```
*   **Why `--build`?** Prevents "stale code" confusion where changes to `Dockerfile` or dependencies aren't picked up.
*   **What this does:**
    1.  Builds the application container (matching Prod image).
    2.  Starts `db` (Postgres 14).
    3.  Starts `backend` with **Hot Reload** enabled.
    4.  **Auto-Migrates** the database on startup.

### Architectural Differences (Dev vs Prod)

| Feature | Local Dev (`docker-compose`) | Production (EC2) |
| :--- | :--- | :--- |
| **Code Source** | Volume Mount (`/app/app`) | Baked Image |
| **Migrations** | Auto-Run on Startup | Explicit `docker run` Release Phase |
| **Reload** | Hot Reload (Watch Files) | Static Immutable Artifact |
| **Network** | `backend` talks to `db` | `backend` talks to RDS Endpoint |

*Reasoning:* We trade "Exact Startup Parity" for "Developer Experience" (Hot Reload). The logical outcome (App + Schema) remains consistent.

---

## 3. Migration & Schema Handling

**Protocol:**
*   **Automatic:** The `backend` container runs `alembic upgrade head` every time it starts.
*   **Manual (Creating Migrations):**
    ```powershell
    # 1. Create Migration File
    docker compose exec backend alembic revision --autogenerate -m "description"

    # 2. Apply (if startup didn't catch it, or to test)
    docker compose exec backend alembic upgrade head
    ```

**Safety Rule:**
Never edit the database schema manually. Always use Alembic.

---

## 4. One-Off Ops & Scripts

**The "Exec" Pattern:**
To run backfills, admin scripts, or verify data, you MUST use the running container.

**Correct Way:**
```powershell
docker compose exec backend python scripts/backfill_created_by.py
```

**Why?**
*   Uses the exact Python environment (deps, versions) as the app.
*   Has the correct internal network access to the DB (`db` host).
*   Avoids credential leakage (uses env vars already in container).

**FORBIDDEN:**
```powershell
# DO NOT DO THIS
python backend/scripts/backfill_created_by.py
```

---

## 5. Data & State Management

*   **Persistence:** Database data is stored in the `postgres_data` Docker volume. It survives restarts.
*   **Resetting State:**
    ```powershell
    # 💥 DESTROY ALL DATA
    docker compose down -v
    docker compose up --build
    ```
    *Note: This wipes the volume. The app will auto-migrate and (optionally) auto-seed on next boot.*

---

## 6. Failure Modes & Guardrails

| Issue | Symptom | Fix |
| :--- | :--- | :--- |
| **Database Not Ready** | Logs: `Connection refused` | Wait. `wait-for-db.sh` handles this auto-magically. |
| **Migration Lock** | Logs: `alembic.util.command.CommandError` | `docker compose restart backend` (usually clears transient locks). |
| **Script Import Error** | `ModuleNotFoundError` | Ensure you run via `exec`. Check `PYTHONPATH` in Dockerfile. |
| **Port Conflict** | `Bind for 0.0.0.0:5432 failed` | Stop local Postgres service or other containers (`docker compose down`). |

---

## 7. Readiness Checklist

Before pushing code, verify:

- [ ] **Clean Startup:** `docker compose down -v && docker compose up --build` starts without error.
- [ ] **Migration Check:** `docker compose exec backend alembic check` returns no pending changes.
- [ ] **Ops Check:** If you wrote a script, verify it runs via `docker compose exec`.
- [ ] **Test Check:** `docker compose exec backend pytest` passes.

---

## 8. Final Recommendation

**Adhere to the "Exec Pattern".**
Stop installing `requirements.txt` on your host machine. Stop running python scripts from PowerShell/Terminal directly. Usage of the host environment creates drift and breaks production reliability.

**Adopt:**
- `docker compose up`
- `docker compose exec ...`
