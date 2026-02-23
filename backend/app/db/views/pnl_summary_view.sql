CREATE OR REPLACE VIEW pnl_summary AS

WITH
  -- 1) Sales per mart per day, from invoice items
  sales AS (
    SELECT
      inv.warehouse_id AS warehouse_id,
      m2.id       AS mart_id,
      DATE(ii.invoice_date) AS date,
      SUM(ii.total)       AS total_sales
    FROM invoice_item ii
    JOIN invoice inv
      ON ii.invoice_id = inv.id
    join mart m2 
    on ii.store_name = m2.name
    GROUP BY inv.warehouse_id, m2.id, DATE(ii.invoice_date)
  ),
  -- 2) Cost per mart per day, from dispatches joined to stock entry
  cost AS (
    SELECT
      de.warehouse_id AS warehouse_id,
      de.mart_id,
      de.dispatch_date      AS date,
      SUM(de.quantity * se.price_per_unit) AS total_cost
    FROM dispatch_entry de
    JOIN stockentry se
      ON de.batch_id = se.batch_id
    GROUP BY de.warehouse_id, de.mart_id, de.dispatch_date
  )
SELECT
  COALESCE(s.warehouse_id, c.warehouse_id) AS warehouse_id,
  COALESCE(s.mart_id, c.mart_id) AS mart_id,
  m.name                         AS mart_name,
  COALESCE(s.date, c.date)       AS date,
  COALESCE(s.total_sales, 0::numeric)     AS total_sales,
  COALESCE(c.total_cost,  0::numeric)     AS total_purchase,
  COALESCE(s.total_sales, 0::numeric) - COALESCE(c.total_cost, 0::numeric) AS profit
FROM sales s
FULL OUTER JOIN cost c
  ON s.warehouse_id = c.warehouse_id
  AND s.mart_id = c.mart_id
  AND s.date   = c.date
LEFT JOIN mart m
  ON m.id = COALESCE(s.mart_id, c.mart_id)
ORDER BY warehouse_id, mart_id, date;
