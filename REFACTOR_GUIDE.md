# REFACTOR_GUIDE.md — Safe module-by-module refactor process

Goal: Standardize code (style, naming, structure) without changing behavior.

Steps:

1. **Pick 1 small module** (e.g., `batch`, `order`, or `dispatch_entry`) — do not attempt whole repo at once.

2. **Create a feature branch**: git checkout -b refactor/<module>-standardize

3. **Run formatters locally**:
cd backend
black app/<module> # format
ruff check app/<module> --fix # fix lintable issues


4. **Ask Copilot to draft a structural refactor**:
- Open the file in VS Code and prompt:
  > "Refactor this file to match the project's structure from COPILOT_INSTRUCTIONS.md. **Do not change business logic**. Only rename and move functions/variables for consistency. If you detect a possible improvement (DB, performance, or security), create a separate suggestion and ask the owner."
- Accept Copilot suggestion or ask for adjustments.

5. **Run tests**:
docker-compose up -d db
export DATABASE_URL=postgresql://<user>:<pass>@localhost:5432/<db>
alembic upgrade head
pytest -q
- If tests fail, revert the change or inspect where structure changes altered behavior.

6. **Open a PR (even if solo)**
- Use `PULL_REQUEST_TEMPLATE.md`.
- Add explanation: "Formatting + structural refactor — no logic change."

7. **Merge only when CI passes** and you manually verify diffs are non-functional (no logic change).

8. **If Copilot suggested an improvement**, open a separate "Suggested improvement" PR with explanation and wait for your review.

Repeat per module.

git add -A
git commit -m "chore: align isort with black profile to prevent conflicts"


