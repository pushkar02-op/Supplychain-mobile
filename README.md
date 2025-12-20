# Fruit Vendor Tool (AGRO) - Monorepo

**Maintainer Runbook & Operations Manual**

> **⚠️ WARNING TO AI ASSISTANTS & NEW ENGINEERS:**
> This repository follows strict architectural rules.
> **Backend:** Container-First, Explicit Migrations.
> **Frontend:** Riverpod-First, Layered Architecture, Explicit Config.
> **Do NOT deviate from these patterns.**

---

## 1. Project Overview

The AGRO Supply Chain tool is a mobile-first platform for auditing, tracking, and selling produce.
This repository contains the complete stack:

*   **`backend/`**: FastAPI (Python) service. Primary source of truth.
*   **`mobile/`**: Flutter (Dart) application. Primary user interface.

---

## 2. Quick Start (The Canonical Way)

To run the complete system from zero:

### Step 1: Start the Backend (Docker)
We use a **Container-First** approach. Do NOT run Python locally.

```powershell
# From the root directory:
docker compose down -v
docker compose up --build
```
*   **Result:** Backend running at `http://localhost:8000` (API at `/v1`).
*   **Docs:** `http://localhost:8000/docs`.

### Step 2: Start the Frontend (Flutter)
The app **WILL NOT START** without an explicit `API_BASE_URL`.

**Option A: Android Emulator**
```powershell
cd mobile
flutter run --dart-define="API_BASE_URL=http://10.0.2.2:8000/v1"
```
*   *Note: `10.0.2.2` maps to the host's localhost.*

**Option B: Physical Device**
```powershell
cd mobile
flutter run --dart-define="API_BASE_URL=http://YOUR_LAN_IP:8000/v1"
```

**Option C: VS Code**
Open `.vscode/launch.json` and run **"SupplyChain Mobile (Android Emulator)"**.

---

## 3. Backend Operations (Summary)

> **Full Documentation:** [backend/README.md](./backend/README.md)

**Golden Rules:**
1.  **NEVER** run Python from your host machine. Use `docker compose exec backend ...`
2.  **NEVER** edit the database schema manually. Use Alembic.
3.  **NEVER** commit code without running `docker compose up --build`.

**Common Commands:**
*   **Reset Data:** `docker compose down -v && docker compose up --build`
*   **Create Migration:** `docker compose exec backend alembic revision --autogenerate -m "msg"`
*   **Apply Migration:** `docker compose exec backend alembic upgrade head`

---

## 4. Frontend Operations (Mobile)

> **Full Documentation:** [mobile/README.md](./mobile/README.md)

**Architecture:**
*   **State:** `flutter_riverpod` (AsyncNotifier).
*   **Routing:** `go_router` (Reactive Auth).
*   **Network:** `dio` (Singleton layered Client).

**Golden Rules (CRITICAL):**
1.  **NEVER hardcode API URLs.** Always use `--dart-define`.
2.  **NEVER call APIs from Widgets.** Use Controllers (`AsyncNotifier`).
3.  **NEVER use `setState` for business logic.** Use Riverpod.
4.  **NEVER navigate manually on auth.** Update `AuthProvider`; the router will react.

**Reference Patterns:**
*   **Auth:** `lib/providers/auth_provider.dart` (Source of Truth).
*   **Feature:** `lib/screens/stock_list_screen.dart` (Reference Implementation).
    *   No `setState`.
    *   No API calls.
    *   Pure `ConsumerWidget`.

**Error Handling:**
*   Repositories throw `AppException` hierarchy (Network, Unauthorized, Validation).
*   UI renders `error.toString()` from the Controller state.
*   **Do NOT** inspect `DioException` in the UI.

---

## 5. Deployment & Release

*   **Backend:**
    *   **Deployment Pipeline:** [DEPLOYMENT_PIPELINE_DESIGN.md](./DEPLOYMENT_PIPELINE_DESIGN.md)
    *   **Strategy:** Build Image → Safety Check (Migration) → Rollout.
    *   **Zero Downtime:** Failed migrations abort deploy before affecting runtime.

*   **Frontend:**
    *   Build standard APK/IPA artifact using `flutter build`.
    *   Inject `API_BASE_URL` at runtime or build-time (flavor strategy).

---

## 6. Documentation Index

**System:**
*    [FRONTEND_STABILIZATION_RFC.md](./brain/04fdc17d-e878-4d4a-8cf4-21aba3200923/FRONTEND_STABILIZATION_RFC.md) (Architecture Decision Record)

**Backend:**
*   [backend/README.md](./backend/README.md)
*   [LOCAL_DEVELOPMENT_RFC.md](./LOCAL_DEVELOPMENT_RFC.md)
*   [BACKFILL_RUNBOOK.md](./BACKFILL_RUNBOOK.md)

**Frontend:**
*   [mobile/README.md](./mobile/README.md) (Deep Dive)