select
  customer_id,
  customer_name,
  customer_email,
  customer_segment,
  order_count,
  total_spent,
  last_order_id,
  updated_at,
  currency
from streaming.customer_sales
