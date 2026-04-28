-- No customer360 data available. Use distinct customers from sales orders.
select
  customer_id,
  customer_name,
  customer_email,
  customer_segment,
  currency
from {{ ref('stg_sales_order') }}
group by 1, 2, 3, 4, 5
