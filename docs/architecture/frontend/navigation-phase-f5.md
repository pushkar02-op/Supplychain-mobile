# Frontend Navigation Architecture — Phase F5

## Overview

Phase F5.1 introduces a mobile-first bottom navigation pattern, replacing the previous Dashboard-centric card navigation.

## Before vs After

### Before (Dashboard-Centric)
```
Login → Dashboard (card grid) → Tap card → Screen
                              ↓
                         Back to Dashboard
```

### After (Bottom Navigation)
```
Login → AppScaffold (with BottomNavigationBar)
              ↓
    ┌─────────┼──────────┬──────────┬──────────┬──────────┐
    │         │          │          │          │          │
 Overview   Stock     Orders    Dispatch     More
    │         │          │          │          │
OverviewScreen  StockList  OrdersScreen  DispatchList  MoreHubScreen
                                                         ↓
                                                (Inventory, MartBills,
                                                 Items, AliasMapping,
                                                 Rejections, Admin...)
```

## Tab Responsibilities

| Tab | Entry Screen | Purpose |
|-----|-------------|---------|
| Overview | `OverviewScreen` | Read-only daily snapshot (landing tab) |
| Stock | `StockListScreen` | Daily stock entry management |
| Orders | `OrdersScreen` | Order creation and dispatch flow |
| Dispatch | `DispatchListScreen` | Dispatch tracking and reversal |
| More | `MoreHubScreen` | Secondary screens + Admin section |

## More Hub Sections

### Reference Section
- Inventory — View current stock levels
- Mart Bills — Upload and manage invoices  
- Items — Manage item catalog
- Alias Mapping — Map invoice items to master items
- Rejections — Track rejected items

### Administration Section (Admin Only)
- Inventory Health — Ledger health monitoring
- Drift Report — Reconciliation details
- UOM Diagnostics — Configuration issues

## Admin Isolation

Admin screens are protected at two levels:
1. **Route Level**: Paths `/admin/*` are gated by GoRouter redirect
2. **UI Level**: Admin section in MoreHubScreen only renders if `authProvider.value?.isAdmin == true`

## Key Files

| File | Purpose |
|------|---------|
| `widgets/app_scaffold.dart` | Main scaffold with BottomNavigationBar |
| `screens/more_hub_screen.dart` | Hub for secondary navigation |
| `routes/app_router.dart` | Updated routing with `/main` entry |

## What Was NOT Changed

- ❌ No screen internals modified
- ❌ No backend APIs changed
- ❌ No business logic altered
- ❌ No routes removed
- ❌ All existing deep link routes preserved

## Migration Notes

- `/dashboard` route redirects to `/main`
- E2E tests expecting Dashboard tiles need updates (Phase F5.2)
- Login redirect now points to `/main` instead of `/dashboard`
