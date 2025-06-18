CREATE OR REPLACE VIEW inventory_summary AS
  SELECT iv.item_id,i.name,uom.code  unit, SUM(CASE WHEN iv.txn_type = 'IN' THEN iv.base_qty
           WHEN iv.txn_type = 'OUT' THEN -iv.base_qty
           ELSE 0 END)  AS current_stock FROM inventory_txn iv
           join item i on i.id = iv.item_id
           left join uom on i.default_uom_id = uom.id
GROUP BY iv.item_id, i.name, uom.code;
