-- No product master data available. Use distinct products from sales order line items.
select
  sku as product_id,
  product_name,
  currency
from {{ ref('stg_sales_order_line_item') }}
group by 1, 2, 3
