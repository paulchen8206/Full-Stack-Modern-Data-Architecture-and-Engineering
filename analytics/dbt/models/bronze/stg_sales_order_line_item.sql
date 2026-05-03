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
  orderid as order_id,
  ordertimestamp as order_timestamp,
  customerid as customer_id,
  customername as customer_name,
  lineitemid as line_item_id,
  sku,
  productname as product_name,
  cast(quantity as integer) as quantity,
  cast(null as double) as unit_price,
  cast(null as double) as line_total,
  currency
from warehouse.landing.sales_order_line_item
{% endif %}
