
  create view "analytics"."public_stage"."stg_customer_sales__dbt_tmp"
    
    
  as (
    select
  customerid as customer_id,
  customername as customer_name,
  customeremail as customer_email,
  customersegment as customer_segment,
  ordercount::bigint as order_count,
  totalspent::numeric as total_spent,
  lastorderid as last_order_id,
  updatedat as updated_at,
  currency
from landing.customer_sales
  );