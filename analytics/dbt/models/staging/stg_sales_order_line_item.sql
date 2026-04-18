select
  orderid as order_id,
  ordertimestamp as order_timestamp,
  customerid as customer_id,
  customername as customer_name,
  lineitemid as line_item_id,
  sku,
  productname as product_name,
  quantity::int as quantity,
  unitprice::numeric as unit_price,
  linetotal::numeric as line_total,
  currency
from landing.sales_order_line_item
