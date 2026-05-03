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
  customerid as customer_id,
  customername as customer_name,
  customeremail as customer_email,
  customersegment as customer_segment,
  cast(ordercount as bigint) as order_count,
  cast(null as double) as total_spent,
  lastorderid as last_order_id,
  updatedat as updated_at,
  currency
from warehouse.landing.customer_sales
{% endif %}
