
  create view "analytics"."public_stage"."stg_sales_order__dbt_tmp"
    
    
  as (
    select
  orderid as order_id,
  ordertimestamp as order_timestamp,
  customerid as customer_id,
  customername as customer_name,
  customeremail as customer_email,
  customersegment as customer_segment,
  currency,
  ordertotal::numeric as order_total,
  lineitemcount::int as line_item_count
from landing.sales_order
  );