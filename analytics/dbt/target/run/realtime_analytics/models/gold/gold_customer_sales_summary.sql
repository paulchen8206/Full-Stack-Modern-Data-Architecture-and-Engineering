
  
    

  create  table "analytics"."public_gold"."gold_customer_sales_summary__dbt_tmp"
  
  
    as
  
  (
    with sales as (
  select * from "analytics"."public_stage"."stg_customer_sales"
),
orders as (
  select * from "analytics"."public_stage"."stg_sales_order"
),
line_items as (
  select * from "analytics"."public_stage"."stg_sales_order_line_item"
),
line_item_rollup as (
  select
    customer_id,
    sum(line_total) as line_item_total,
    count(*) as total_line_items,
    max(order_timestamp) as last_line_item_at
  from line_items
  group by customer_id
)
select
  s.customer_id,
  max(s.customer_name) as customer_name,
  max(s.customer_email) as customer_email,
  max(s.customer_segment) as customer_segment,
  max(s.currency) as currency,
  max(s.order_count) as latest_order_count,
  max(s.total_spent) as latest_total_spent,
  coalesce(l.line_item_total, 0) as recomputed_total_from_line_items,
  coalesce(l.total_line_items, 0) as total_line_items,
  count(distinct o.order_id) as observed_orders,
  max(o.order_timestamp) as last_order_timestamp,
  max(s.updated_at) as projection_updated_at,
  max(l.last_line_item_at) as last_line_item_timestamp
from sales s
left join orders o
  on s.customer_id = o.customer_id
left join line_item_rollup l
  on s.customer_id = l.customer_id
group by s.customer_id, l.line_item_total, l.total_line_items
  );
  