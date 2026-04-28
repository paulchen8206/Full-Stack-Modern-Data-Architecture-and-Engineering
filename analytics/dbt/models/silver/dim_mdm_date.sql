-- No date dimension available. Use distinct order dates from sales order line items.
select
  cast(order_timestamp as date) as order_date
from {{ ref('stg_sales_order_line_item') }}
group by 1
