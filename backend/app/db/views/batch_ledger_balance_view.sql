CREATE OR REPLACE VIEW batch_ledger_balance_view AS
  SELECT
    batch_id,
    CAST(SUM(
        CASE
            WHEN txn_type IN ('IN', 'ADJUST') THEN base_qty
            WHEN txn_type IN ('OUT', 'REJECT', 'DISPATCH') THEN -base_qty
            ELSE 0
        END
    ) AS NUMERIC(10,3)) AS ledger_qty
  FROM inventory_txn
  WHERE batch_id IS NOT NULL
  GROUP BY batch_id;
