CREATE OR REPLACE VIEW inventory_summary AS
  SELECT b.item_id,
         i.name AS item_name,
         b.unit,
         SUM(b.quantity) AS available_quantity
  FROM batch AS b
  JOIN item AS i ON i.id = b.item_id
  WHERE b.quantity > 0
  GROUP BY b.item_id, i.name, b.unit;
