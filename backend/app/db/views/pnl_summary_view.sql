CREATE OR REPLACE VIEW pnl_summary AS

WITH
  -- 1) Sales per mart per day, from invoice items
  sales AS (
    SELECT
      ii.store_name       AS mart_name,
      DATE(ii.invoice_date) AS date,
      SUM(ii.total)       AS total_sales
    FROM invoice_item ii
    GROUP BY ii.store_name, DATE(ii.invoice_date)
  ),
  -- 2) Cost per mart per day, from dispatches joined to stock entry
  cost AS (
    SELECT
      de.mart_name          AS mart_name,
      de.dispatch_date      AS date,
      SUM(de.quantity * se.price_per_unit) AS total_cost
    FROM dispatch_entry de
    JOIN stockentry se
      ON de.batch_id = se.batch_id
    GROUP BY de.mart_name, de.dispatch_date
  )
SELECT
  COALESCE(s.mart_name, c.mart_name) AS mart_name,
  COALESCE(s.date, c.date)           AS date,
  COALESCE(s.total_sales, 0)         AS total_sales,
  COALESCE(c.total_cost,  0)         AS total_purchase,
  COALESCE(s.total_sales, 0) - COALESCE(c.total_cost, 0) AS profit
FROM sales s
FULL OUTER JOIN cost c
  ON s.mart_name = c.mart_name
  AND s.date      = c.date
ORDER BY mart_name, date;
