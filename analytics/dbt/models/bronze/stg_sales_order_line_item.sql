{% if target.type == 'postgres' %}
select
  orderid as order_id,
  ordertimestamp as order_timestamp,
  customerid as customer_id,
  customername as customer_name,
  lineitemid as line_item_id,
  sku,
  productname as product_name,
  quantity,
  unitprice as unit_price,
  linetotal as line_total,
  currency
from landing.sales_order_line_item
{% else %}
select
  order_id,
  order_timestamp,
  customer_id,
  customer_name,
  line_item_id,
  sku,
  product_name,
  quantity,
  unit_price,
  line_total,
  currency
from streaming.sales_order_line_item
{% endif %}
