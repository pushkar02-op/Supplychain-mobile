---
description: Standard startup sequence to ingest governance and business rules.
---

# Agent Boot Sequence

This workflow ensures the agent is aware of the authoritative rules and strict governance hierarchy before performing any work.

1.  **Read Governance Constitution**
    Read `docs/GOVERNANCE.md` to understand the authority hierarchy and documentation-first rules.
    *(Files: `docs/GOVERNANCE.md`)*

2.  **Read Business Logic Law**
    Read `docs/business_rules_and_enforcement.md` to understand immutable business constraints.
    *(Files: `docs/business_rules_and_enforcement.md`)*

3.  **Read Agent Rules**
    Read `.agent/rules/documentation-enforcement-rule.md` to confirm the specific agent enforcement contract.
    *(Files: `.agent/rules/documentation-enforcement-rule.md`)*

4.  **Acknowledge Status**
    Print a short summary confirming that the "Context Boot" is complete and you are ready to proceed under strict governance.
