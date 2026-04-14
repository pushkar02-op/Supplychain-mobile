# Known Risks & Hot Spots

> Active risks, known tech debt, and subsystem warnings. Updated by the
> Planner or by `close-session.sh` when sessions surface new risks.
> Items are not removed — they are marked RESOLVED with a date.

---

## Format

```
### RISK-NNN: <title>
**Severity:** HIGH | MEDIUM | LOW
**Subsystem:** <subsystem name>
**Identified:** YYYY-MM-DD  |  **Session:** <slug>
**Status:** OPEN | MITIGATED | RESOLVED (YYYY-MM-DD)
**Description:** <what the risk is>
**Mitigation:** <what reduces the risk, or NONE>
**Resolution path:** <what would fully close this>
```

---

## Active Risks

### RISK-001: Naming inconsistency — invoice / mart_bill table
**Severity:** LOW
**Subsystem:** mart_bill
**Identified:** 2026-04-14  |  **Session:** 2026-04-14-g5-glossary
**Status:** OPEN
**Description:** The DB table is named `invoice` and the DB model for
`MartBillItem` uses table name `invoice_item`. These are legacy names
that predate the canonical `MartBill` / `MartBillItem` terminology.
New code uses the canonical names, but the table names create confusion
for anyone reading raw SQL or migration files.
**Mitigation:** `04-GLOSSARY.md` documents this inconsistency in the
Known Naming Inconsistencies appendix.
**Resolution path:** A migration renaming `invoice` → `mart_bill` and
`invoice_item` → `mart_bill_item`. High coordination cost — requires
updating all raw SQL references.

### RISK-002: Flutter StockTransaction model is a synonym for StockEntry
**Severity:** LOW
**Subsystem:** mobile
**Identified:** 2026-04-14  |  **Session:** 2026-04-14-g5-glossary
**Status:** OPEN
**Description:** `mobile/lib/models/stock_transaction.dart` is a view
model that represents a `StockEntry` for display. Its name (`StockTransaction`)
conflicts with `InventoryTransaction` and could mislead developers into
treating it as a canonical entity synonym.
**Mitigation:** `04-GLOSSARY.md` documents this under Known Naming
Inconsistencies.
**Resolution path:** Rename to `StockEntryView` or `StockEntryDisplay`
in a dedicated Flutter refactor brief.

---

## Resolved Risks

_Move resolved items here._
