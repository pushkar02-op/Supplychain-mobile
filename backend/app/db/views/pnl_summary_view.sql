CREATE OR REPLACE VIEW pnl_summary AS

WITH
  -- 1) Sales per mart per day, from invoice items
  sales AS (
    SELECT
      m2.id       AS mart_id,
      DATE(ii.invoice_date) AS date,
      SUM(ii.total)       AS total_sales
    FROM invoice_item ii
    join mart m2 
    on ii.store_name = m2.name
    GROUP BY m2.id, DATE(ii.invoice_date)
  ),
  -- 2) Cost per mart per day, from dispatches joined to stock entry
  cost AS (
    SELECT
      de.mart_id,
      de.dispatch_date      AS date,
      SUM(de.quantity * se.price_per_unit) AS total_cost
    FROM dispatch_entry de
    JOIN stockentry se
      ON de.batch_id = se.batch_id
    GROUP BY de.mart_id, de.dispatch_date
  )
SELECT
  COALESCE(s.mart_id, c.mart_id) AS mart_id,
  m.name                         AS mart_name,
  COALESCE(s.date, c.date)       AS date,
  COALESCE(s.total_sales, 0::numeric)     AS total_sales,
  COALESCE(c.total_cost,  0::numeric)     AS total_purchase,
  COALESCE(s.total_sales, 0::numeric) - COALESCE(c.total_cost, 0::numeric) AS profit
FROM sales s
FULL OUTER JOIN cost c
  ON s.mart_id = c.mart_id
  AND s.date   = c.date
LEFT JOIN mart m
  ON m.id = COALESCE(s.mart_id, c.mart_id)
ORDER BY mart_id, date;
