CREATE OR REPLACE VIEW inventory_signal_view AS
SELECT
    warehouse_id,
    item_id,
    CAST(SUM(CASE WHEN created_at >= (NOW() - INTERVAL '7 days') THEN base_qty ELSE 0 END) AS NUMERIC(10,3)) as out_last_7d,
    CAST(SUM(CASE WHEN created_at >= (NOW() - INTERVAL '14 days') AND created_at < (NOW() - INTERVAL '7 days') THEN base_qty ELSE 0 END) AS NUMERIC(10,3)) as out_prev_7d
FROM inventory_txn
WHERE txn_type = 'OUT'
GROUP BY warehouse_id, item_id;
