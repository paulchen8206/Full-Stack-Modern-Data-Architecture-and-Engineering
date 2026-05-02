with line_items as (
  select *
  from {{ ref('stg_sales_order_line_item') }}
),
orders as (
  select *
  from {{ ref('stg_sales_order') }}
),
dim_customer as (
  select *
  from {{ ref('dim_mdm_customer') }}
),
dim_product as (
  select *
  from {{ ref('dim_mdm_product') }}
),
dim_date as (
  select *
  from {{ ref('dim_mdm_date') }}
)
select
  li.order_id,
  li.line_item_id,
  li.order_timestamp,
  cast(li.order_timestamp as date) as order_date,
  dd.date_key,
  li.customer_id,
  li.sku as product_id,
  coalesce(dp.product_name, li.product_name) as product_name,
  li.quantity,
  li.unit_price,
  li.line_total,
  o.order_total,
  o.line_item_count,
  coalesce(li.currency, o.currency, dc.currency, dp.currency) as currency,
  coalesce(dc.customer_name, o.customer_name) as customer_name,
  coalesce(dc.customer_email, o.customer_email) as customer_email,
  coalesce(dc.customer_segment, o.customer_segment) as customer_segment,
  dd.is_weekend
from line_items li
left join orders o
  on li.order_id = o.order_id
left join dim_customer dc
  on li.customer_id = dc.customer_id
left join dim_product dp
  on li.sku = dp.product_id
left join dim_date dd
  on cast(li.order_timestamp as date) = dd.order_date
