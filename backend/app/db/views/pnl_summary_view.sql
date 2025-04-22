CREATE OR REPLACE VIEW pnl_summary AS
  SELECT
    se.received_date   AS date,
    SUM(se.total_cost) AS total_purchase,
    COALESCE(SUM(de.total_revenue), 0) AS total_sales,
    COALESCE(SUM(de.total_revenue), 0) - SUM(se.total_cost) AS profit
  FROM stockentry se
  LEFT JOIN dispatchentry de ON de.dispatch_date = se.received_date
  GROUP BY se.received_date;
