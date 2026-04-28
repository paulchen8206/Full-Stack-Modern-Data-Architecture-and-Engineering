select
  li.order_id,
  li.line_item_id,
  li.order_timestamp,
  cast(li.order_timestamp as date) as order_date,
  li.customer_id,
  li.sku as product_id,
  li.product_name,
  li.quantity,
  li.unit_price,
  li.line_total,
  o.order_total,
  o.line_item_count,
  coalesce(li.currency, o.currency) as currency,
  o.customer_name,
  o.customer_email,
  o.customer_segment
from {{ ref('stg_sales_order_line_item') }} li
left join {{ ref('stg_sales_order') }} o
  on li.order_id = o.order_id
