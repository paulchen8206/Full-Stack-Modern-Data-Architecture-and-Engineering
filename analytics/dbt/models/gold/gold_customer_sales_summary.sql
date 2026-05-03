with sales_ranked as (
  select
    *,
    row_number() over (
      partition by customer_id
      order by updated_at desc nulls last
    ) as rn
  from {{ ref('stg_customer_sales') }}
),
sales as (
  select *
  from sales_ranked
  where rn = 1
),
dim_customer as (
  select * from {{ ref('dim_mdm_customer') }}
),
fact_sales_order as (
  select * from {{ ref('fact_sales_order') }}
),
fact_rollup as (
  select
    customer_id,
    sum(line_total) as recomputed_total_from_line_items,
    count(*) as total_line_items,
    count(distinct product_id) as distinct_products_purchased,
    count(distinct order_id) as observed_orders,
    max(order_timestamp) as last_order_timestamp,
    max(order_date) as last_order_date,
    max(order_timestamp) as last_line_item_timestamp
  from fact_sales_order
  group by customer_id
)
select
  s.customer_id,
  coalesce(c.customer_name, s.customer_name) as customer_name,
  coalesce(c.customer_email, s.customer_email) as customer_email,
  coalesce(c.customer_segment, s.customer_segment) as customer_segment,
  coalesce(c.currency, s.currency) as currency,
  s.order_count as latest_order_count,
  s.total_spent as latest_total_spent,
  coalesce(f.recomputed_total_from_line_items, 0) as recomputed_total_from_line_items,
  coalesce(f.total_line_items, 0) as total_line_items,
  coalesce(f.distinct_products_purchased, 0) as distinct_products_purchased,
  coalesce(f.observed_orders, 0) as observed_orders,
  f.last_order_timestamp,
  f.last_order_date,
    CAST(NULL AS timestamp) as projection_updated_at,
  f.last_line_item_timestamp,
  CAST(NULL AS timestamp) as mdm_customer_updated_at
from sales s
left join dim_customer c
  on s.customer_id = c.customer_id
left join fact_rollup f
  on s.customer_id = f.customer_id
