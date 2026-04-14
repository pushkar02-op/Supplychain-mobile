# AGRO — Context Fetch Template

> Used by the Planner when it needs current repo state before writing a
> brief. Emit this as a **single fenced code block** in the planner chat.
> The human pastes it to an executor. The executor runs it read-only and
> pastes the output back.
>
> Rule: no prose inside the block. The block is the complete instruction.

---

## When to use

- Before designing a feature that touches files you haven't seen in this
  session
- When state.json may be stale and you need current branch / test status
- When you need to know exact function signatures before writing a brief

## What NOT to include

- Any command that writes, creates, deletes, or modifies files
- Any git command beyond `status`, `log`, `diff`, `show`, `branch`,
  `rev-parse`, `ls-files`
- Any command that installs packages or changes environment state

---

## Template

Copy everything inside the fence when emitting to the human:

````
## CONTEXT FETCH REQUEST
Session goal: <one line describing what you are planning>
Read-only. No modifications. Paste full output back to planner.

1. cat .agent/STATE/state.json
2. git status --short
3. git log --oneline -10
4. <additional read-only commands as needed>
   Example: cat backend/app/services/<file>.py
   Example: grep -n "def <function>" backend/app/services/<file>.py
   Example: cat backend/app/db/schemas/<schema>.py

Do not modify anything. Do not commit. Do not create files.
Return the raw output of each command, prefixed with the command number.
````

---

## Filled example

````
## CONTEXT FETCH REQUEST
Session goal: understand current dispatch_entry service before writing ORD-007 hardening brief
Read-only. No modifications. Paste full output back to planner.

1. cat .agent/STATE/state.json
2. git status --short
3. git log --oneline -5
4. grep -n "def " backend/app/services/dispatch_entry.py
5. grep -n "ORD-007\|remaining_qty\|quantity_dispatched" backend/app/services/dispatch_entry.py
6. cat backend/app/db/schemas/dispatch_entry.py

Do not modify anything. Do not commit. Do not create files.
Return the raw output of each command, prefixed with the command number.
````
