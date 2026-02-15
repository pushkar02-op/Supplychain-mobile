# SCREEN_INVENTORY_M0 — Baseline Screen Snapshot

> **Captured**: 2026-02-16  
> **Source**: `mobile/lib/screens/`  
> **Phase**: M0 (Pre-Migration)

---

## All Screens

| # | Screen File | Route | Responsibility | Lines | Riverpod? | Decompose? |
|---|-------------|-------|---------------|------:|:---------:|:----------:|
| 1 | `overview_screen.dart` | Tab 0 via `/main` | Dashboard — today's snapshot, quick actions | 340 | Hybrid | ❌ |
| 2 | `stock_list_screen.dart` | Tab 1 via `/main` | Stock receipt list, void actions | 370 | ✅ | ❌ |
| 3 | `orders_screen.dart` | Tab 2 via `/main` | Order list by date/mart, delete | 456 | ❌ | ❌ |
| 4 | `dispatch_list_screen.dart` | Tab 3 via `/main` | Dispatch list, reversal dialog | 510 | Hybrid | 🟡 |
| 5 | `more_hub_screen.dart` | Tab 4 via `/main` | Secondary navigation hub | 195 | ✅ | ❌ |
| 6 | `stock_entry_screen.dart` | `/stock-entry` | Create stock receipt (+ adjustment) | 700 | ❌ | 🔴 |
| 7 | `order_entry_screen.dart` | `/order-entry` | Create order | 544 | ❌ | 🟡 |
| 8 | `dispatch_entry_screen.dart` | `/dispatch-entry` | Create/edit dispatch | 572 | ❌ | 🔴 |
| 9 | `mart_bill_list_screen.dart` | `/mart-bills` | Bill list + upload + expansion | 763 | ❌ | 🔴 |
| 10 | `pdf_view_screen.dart` | `/pdf-viewer` | PDF bill viewer | 221 | ❌ | ❌ |
| 11 | `rejection_list_screen.dart` | `/rejection-list` | Rejection entry list | 304 | ❌ | ❌ |
| 12 | `rejection_entry_screen.dart` | `/rejection-entry` | Create rejection entry | 251 | ❌ | ❌ |
| 13 | `inventory_screen.dart` | `/inventory` | Inventory ledger + drill-down | 973 | Hybrid | 🔴 |
| 14 | `item_list_screen.dart` | `/items` | Item master list + expansion | 372 | ❌ | ❌ |
| 15 | `item_detail_screen.dart` | `/item-detail` | Item detail + forecast signals | 337 | ❌ | ❌ |
| 16 | `item_management_screen.dart` | `/item-edit` | Create/edit item + UOM config | 839 | ❌ | 🔴 |
| 17 | `alias_mapping_screen.dart` | `/alias-mapping` | Item alias management | 289 | ❌ | ❌ |
| 18 | `dashboard_screen.dart` | `/dashboard` | Legacy dashboard (redirected → `/main`) | 211 | ✅ | ❌ |
| 19 | `admin_diagnostics_screen.dart` | `/admin/uom-diagnostics` | UOM missing config report | 199 | ✅ | ❌ |
| 20 | `admin_inventory_health_screen.dart` | `/admin/ledger/health` | Ledger health summary | 188 | ✅ | ❌ |
| 21 | `admin_inventory_drift_screen.dart` | `/admin/ledger/drift` | Drift report + severity | 143 | ✅ | ❌ |
| 22 | `admin_reconciliation_detail_screen.dart` | (push from admin screens) | Batch reconciliation drill-down | 212 | ✅ | ❌ |

---

## Summary Statistics

| Metric | Value |
|--------|-------|
| **Total screens** | 22 |
| **Total lines** | ~8,896 |
| **Screens using Riverpod (full)** | 7 |
| **Screens using Riverpod (hybrid)** | 3 |
| **Screens with no Riverpod** | 12 |
| **Screens needing decomposition (🔴)** | 5 |
| **Screens borderline (🟡)** | 2 |
| **Screens OK (❌)** | 15 |

---

## Decomposition Targets (> 500 lines)

| Screen | Lines | Sections | Priority |
|--------|------:|----------|----------|
| `inventory_screen.dart` | 973 | Filters, list, batch bottom sheet, txn history, stat cards, compact stats | 🔴 Critical |
| `item_management_screen.dart` | 839 | Form, UOM section, alias section, image section | 🔴 Critical |
| `mart_bill_list_screen.dart` | 763 | Upload form, upload results, bill list, bill card (expansion) | 🔴 Critical |
| `stock_entry_screen.dart` | 700 | Receipt form, adjustment form, date picker, item selector | 🔴 High |
| `dispatch_entry_screen.dart` | 572 | Entry form, item selector, mart selector | 🟡 Medium |
| `order_entry_screen.dart` | 544 | Entry form, item selector, mart selector | 🟡 Medium |
| `dispatch_list_screen.dart` | 510 | Filters, grouped list, reversal dialog | 🟡 Medium |
