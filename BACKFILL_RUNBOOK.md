# Backfill Runbook: `created_by_id`

**Date:** 2025-12-21
**Script:** `scripts/backfill_created_by.py`
**Scope:** Populate `created_by_id` (Integer) from `created_by` (String) for historic records.

---

## 1. Safety Checks (Pre-Flight)

Ensure Phase 1 (Dual-Write) is complete. Live traffic should be creating records with `created_by_id` populated.

**Check current nulls:**
```sql
SELECT 'batch' as table_name, count(*) FROM batch WHERE created_by_id IS NULL
UNION ALL
SELECT 'invoice', count(*) FROM invoice WHERE created_by_id IS NULL;
```

## 2. Execution Instructions (Docker)

Since the database is only accessible inside the container network, you must run the script using the app container.

### Option A: Local (Docker Compose)
Scripts are now baked into the image at `/app/scripts`.
```powershell
docker compose exec backend python scripts/backfill_created_by.py --dry-run
```

### Option B: Production (One-Off Ops Container)
Use the deployed image to run the script. This ensures you use the exact code version running in production.
```bash
docker run --rm -it \
  -e DATABASE_URL=$PROD_DB_URL \
  my-registry/supplychain-app:latest \
  python scripts/backfill_created_by.py --dry-run
```

## 3. Validation Queries (Post-Operation)

**1. Verify Completeness**
Should return 0 (or count of deleted user records).
```sql
SELECT count(*) FROM batch WHERE created_by_id IS NULL;
```

**2. Verify Integrity**
Ensure the resolved ID matches the username string.
```sql
SELECT b.id, b.created_by, u.username, b.created_by_id
FROM batch b
JOIN "user" u ON b.created_by_id = u.id
WHERE b.created_by != u.username;
-- Should return 0 rows.
```

**3. Inspect Unresolved Records (Deleted Users)**
Confirm that any remaining NULLs are indeed deleted users (not found in User table).
```sql
SELECT b.created_by, count(*) 
FROM batch b 
LEFT JOIN "user" u ON b.created_by = u.username 
WHERE b.created_by_id IS NULL 
AND u.id IS NOT NULL; 
-- Should return 0. If it returns rows, the backfill missed them!
```

## 4. Rollback
If the backfill corrupts data (e.g., wrong IDs):
```sql
UPDATE batch SET created_by_id = NULL WHERE created_by_id IS NOT NULL;
-- Note: This clears NEW valid data too! 
-- Better: Restore from backup if catastrophic, OR Re-run script which is idempotent.
```
