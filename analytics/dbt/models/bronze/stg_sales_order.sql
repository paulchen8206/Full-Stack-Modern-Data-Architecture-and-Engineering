select
  order_id,
  order_timestamp,
  customer_id,
  customer_name,
  customer_email,
  customer_segment,
  currency,
  order_total,
  line_item_count
from streaming.sales_order
