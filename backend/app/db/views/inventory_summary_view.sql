CREATE OR REPLACE VIEW inventory_summary AS
  SELECT iv.item_id,i.name AS item_name,i.default_unit as unit,  SUM(CASE WHEN iv.txn_type = 'IN' THEN iv.base_qty
           WHEN iv.txn_type = 'OUT' THEN -iv.base_qty
           ELSE 0 END) AS available_quantity FROM inventory_txn iv
           join item i on i.id = iv.item_id
GROUP BY iv.item_id, i.name, i.default_unit;
