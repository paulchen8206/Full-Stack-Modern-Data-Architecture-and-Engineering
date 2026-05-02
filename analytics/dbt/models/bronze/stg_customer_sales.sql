{% if target.type == 'postgres' %}
select
  customerid as customer_id,
  customername as customer_name,
  customeremail as customer_email,
  customersegment as customer_segment,
  ordercount as order_count,
  totalspent as total_spent,
  lastorderid as last_order_id,
  updatedat as updated_at,
  currency
from landing.customer_sales
{% else %}
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
{% endif %}
