# Frontend Overview Dashboard — Phase F5.2

## Intent

Provide a calm, read-only landing screen that gives users an immediate snapshot of today's operations without requiring navigation through multiple screens.

## Data Sources

All data comes from **existing backend endpoints**:

| Section | Endpoint | Provider/Service |
|---------|----------|------------------|
| Orders Today | `GET /orders/?order_date={today}` | `OrderService.fetchOrders` |
| Dispatches Today | `GET /dispatch-entries/?dispatch_date={today}` | `DispatchService.fetchDispatches` |
| Stock Entries Today | `GET /stock-entry/?date={today}` | `StockService.fetchStockEntries` |
| System Health | `GET /admin/ledger/health` | `ledgerHealthProvider` |

## Sections

### Today's Operations
- **Orders**: Count of today's orders → navigates to Orders tab
- **Dispatches**: Count of today's dispatches → navigates to Dispatch tab  
- **Stock In**: Count of today's stock entries → navigates to Stock tab

### Quick Actions
Chips for common actions:
- New Stock → `/stock-entry`
- New Order → `/order-entry`
- View Inventory → `/inventory`
- Mart Bills → `/mart-bills`

### System Health (Admin Only)
- Shows ledger health status
- Links to `/admin/ledger/health` for details
- Only visible to admin users (`authProvider.isAdmin`)

## Non-Goals

- ❌ No date picker (always shows TODAY)
- ❌ No charts or analytics visualizations
- ❌ No data editing from this screen
- ❌ No backend API changes
- ❌ No filters

## Navigation Position

Overview is **Tab 1** in the BottomNavigationBar, making it the landing screen after login.

## Key Files

| File | Purpose |
|------|---------|
| `screens/overview_screen.dart` | Overview screen implementation |
| `widgets/app_scaffold.dart` | Updated with Overview as first tab |
