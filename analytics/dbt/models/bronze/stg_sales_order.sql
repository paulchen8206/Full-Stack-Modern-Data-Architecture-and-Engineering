{% if target.type == 'postgres' %}
select
  orderid as order_id,
  ordertimestamp as order_timestamp,
  customerid as customer_id,
  customername as customer_name,
  customeremail as customer_email,
  customersegment as customer_segment,
  currency,
  ordertotal as order_total,
  lineitemcount as line_item_count
from landing.sales_order
{% else %}
select
  order_id,
  order_timestamp,
  customer_id,
  customer_name,
  customer_email,
  customer_segment,
  currency,
  order_total,
  line_item_count
from streaming.sales_order
{% endif %}
