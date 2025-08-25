# COPILOT_INSTRUCTIONS.md (ROOT) — Canonical rules for Copilot & contributors

**Purpose**: This file is the single source-of-truth that Copilot (and any human) should follow when adding, refactoring, or formatting code. **Any automated change must NOT modify business logic** without explicit approval from the repo owner.

---

## Project basics (short)

- Name: Fruit Vendor Tool (backend in `backend/app/`, frontend in `mobile/`).
- Backend stack: FastAPI + SQLAlchemy + Alembic + PostgreSQL.
- Tests: pytest (backend).
- DB Migrations: `backend/alembic/` — always use Alembic.
- Top-level entry: `backend/app/main.py`.

(There is an existing developer guide under `.github/`; this file is the canonical, stricter rule set for AI assistants and code generators.) See `.github/COPILOT_INSTRUCTIONS.md` for broader context. :contentReference[oaicite:6]{index=6}

---

## Strict rules (Must follow)

1. **Never change business logic while refactoring**. You may:
   - Reformat code.
   - Rename variables to match style.
   - Move code between modules to match repo structure.
   - Extract helper functions — but only if behavior is identical.
2. **If any change touches DB schema, or suggests a behavior/optimization change, _ask the repo owner_ before applying.**
   - The assistant should present a short PR description + rationale and wait for approval.
3. **Folder structure:**
   - Routes: `backend/app/api/` (APIRouter-based).
   - Models: `backend/app/db/models/`
   - Schemas: `backend/app/db/schemas/`
   - Services (business logic): `backend/app/services/`
   - Utils: `backend/app/utils/`
   - Alembic migrations: `backend/alembic/`
4. **Auditing fields**: All major tables must include:
   - `created_at`, `created_by`, `updated_at`, `updated_by`
5. **Secrets & config**:
   - No hard-coded secrets. Use environment variables or `backend/.env`.
6. **Formatting & lint**:
   - Use `black` for formatting and `ruff` for linting. Import sorting via `isort` where needed.
7. **Testing**:
   - Any refactor touching public API must include or update tests (pytest).
8. **APIs**:
   - Version routes (e.g., `/v1/...`) where you add new routes.
   - Use Pydantic v2 schemas for request/response (with `model_config = dict(from_attributes=True)` pattern).
9. **Error handling**:
   - Use `AppException` for domain errors and `register_exception_handlers` for global handling.
10. **PR policy**:

- Always work in a feature branch and open a PR. Even solo, use PR to review and run CI.

---

## Prompts and phrasing for Copilot / AI

When you ask Copilot to refactor a file, use prompts like:

- _“Refactor this file to follow the project standards in COPILOT_INSTRUCTIONS.md. **Do not change business logic** — only standardize naming, imports, structure, formatting. If you find a potential improvement (performance, security, DB) produce a separate suggestion and ask the owner.”_
- _“Create a PR draft that: (1) formats files with black, (2) applies isort, (3) leaves logic unchanged. Include the list of files changed and the reasons.”_

---

## Refactor rules (legacy code)

- Run `black` + `ruff --fix` first.
- Then ask Copilot to _rewrite_ the file to match folder/module patterns, keeping all tests passing.
- If Copilot suggests code that might modify behavior (new DB query shape, caching, different join), it **must** create a separate MR "Suggested improvement" and not merge without manual approval.

---

## Example checklist to include in every PR

- [ ] Code formatted by `black` (run locally).
- [ ] `ruff` passes or fixes applied.
- [ ] No secrets were added.
- [ ] If DB schema changes: Alembic migration included.
- [ ] If any notable improvement suggested — owner approved.

---

## Where to look for more context

- `backend/alembic/env.py` — migration + view application logic (CI will run migrations). :contentReference[oaicite:8]{index=8}
- `backend/app/main.py` — startup applies migrations at runtime. :contentReference[oaicite:9]{index=9}

---
