# Mart Bill API Contract (Frozen Status)
**Version:** v1
**Status:** Frozen
**Date:** 2026-01-12
**Source:** `backend/app/api/mart_bill.py`
**Base URL:** `/mart-bills`

## 1. Data Schemas
### MartBillRead
*Output model for all read/write operations.*
| Field | Type | notes |
| :--- | :--- | :--- |
| `id` | int | Primary Key |
| `mart_id` | int | |
| `mart_name` | Optional[str] | |
| `invoice_date` | date | |
| `total_amount` | float | |
| `file_path` | str | Relative storage path |
| `status` | str | e.g., "NEEDS_REVIEW", "VERIFIED" |
| `locked_at` | Optional[datetime] | Set when verified |
| `locked_by` | Optional[str] | Username/Fullname |
| `remarks` | Optional[str] | |
| `created_at` | datetime | |
| `updated_at` | datetime | |

### MartBillUpdate
*Input model for updates.*
| Field | Type | Required |
| :--- | :--- | :--- |
| `remarks` | str | No (Optional) |

> [!NOTE]
> Only `remarks` can be updated via PUT. All other fields are immutable via this endpoint.

## 2. Endpoints

### 2.1 Upload Bill
**POST** `/upload`
- **Input:** `files` (List[UploadFile], multipart/form-data)
- **Validation:** Must be `.pdf`.
- **Output:** `List[dict]` (Processing results)

### 2.2 List Bills
**GET** `/`
- **Query Params:**
  - `invoice_date`: YYYY-MM-DD
  - `mart_id`: int
  - `search`: str
  - `skip`: int (default 0)
  - `limit`: int (default 20, max 50)
- **Output:** Paginated JSON response `{items: [...], total: int, ...}`

### 2.3 Get Bill
**GET** `/{bill_id}`
- **Output:** `MartBillRead`
- **Errors:** 404 if not found.

### 2.4 Update Bill
**PUT** `/{bill_id}`
- **Input:** `MartBillUpdate` (JSON)
- **Output:** `MartBillRead`
- **Logic:** Updates remarks only.

### 2.5 Verify (Lock)
**POST** `/{bill_id}/verify`
- **Output:** `MartBillRead`
- **Side Effect:** Sets `locked_at` and `locked_by`.

### 2.6 Unverify (Unlock)
**POST** `/{bill_id}/unverify`
- **Output:** `MartBillRead`
- **Side Effect:** Resets status to `NEEDS_REVIEW` (or equivalent).

### 2.7 Replace File
**POST** `/{bill_id}/replace-file`
- **Input:** `file` (UploadFile)
- **Validation:** Must be `.pdf`.
- **Side Effect:** Resets status to `NEEDS_REVIEW`.
- **Output:** `MartBillRead`

### 2.8 Download PDF
**GET** `/{bill_id}/download`
- **Output:** `FileResponse` (application/pdf)
- **Errors:** 404 if DB record missing OR file missing on disk.

### 2.9 Delete Bill
**DELETE** `/{bill_id}`
- **Output:** 204 No Content

## 3. Coupling Notes
- **Frontend Pagination:** The API supports both `skip/limit` and legacy `page/page_size`. Frontend likely migrating to `skip/limit`.
- **Immutability:** The `MartBillUpdate` schema strictly enforces that core financial data (`amount`, `date`) cannot be edited via PUT. This implies the existence of a "Ledger First" constraint where corrections might require void/re-entry or file replacement.

## 4. Known Issues
> [!WARNING]
> One critical issue known at the time of freeze:
> **Double Unverify Call:** The `unverify` endpoint logic calls `unverify_mart_bill` **twice** sequentially in the source code.
> ```python
> bill = unverify_mart_bill(...)
> bill = unverify_mart_bill(...) # Repeated call
> ```
