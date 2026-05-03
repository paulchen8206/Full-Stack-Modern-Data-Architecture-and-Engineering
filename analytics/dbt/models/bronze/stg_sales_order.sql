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
  orderid as order_id,
  ordertimestamp as order_timestamp,
  customerid as customer_id,
  customername as customer_name,
  customeremail as customer_email,
  customersegment as customer_segment,
  currency,
  cast(ordertotal as double) as order_total,
  cast(lineitemcount as integer) as line_item_count
from warehouse.landing.sales_order
{% endif %}
