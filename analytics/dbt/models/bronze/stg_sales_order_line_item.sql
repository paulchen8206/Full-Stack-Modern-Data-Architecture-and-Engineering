select
  order_id,
  order_timestamp,
  customer_id,
  customer_name,
  line_item_id,
  sku,
  product_name,
  quantity,
  unit_price,
  line_total,
  currency
from streaming.sales_order_line_item
