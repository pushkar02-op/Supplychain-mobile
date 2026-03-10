CREATE OR REPLACE VIEW batch_ledger_balance_view AS
  SELECT
    warehouse_id,
    batch_id,
    CAST(SUM(
        CASE
            WHEN txn_type IN ('IN', 'ADJUST') THEN base_qty
            WHEN txn_type = 'OUT' THEN -base_qty
            ELSE 0
        END
    ) AS NUMERIC(10,3)) AS ledger_qty
  FROM inventory_txn
  WHERE batch_id IS NOT NULL
  GROUP BY warehouse_id, batch_id;
