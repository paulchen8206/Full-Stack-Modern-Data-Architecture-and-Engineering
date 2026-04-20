CREATE SCHEMA IF NOT EXISTS lakehouse.demo
WITH (location = 's3://warehouse/iceberg/demo');

DROP TABLE IF EXISTS lakehouse.demo.sales_order;
CREATE TABLE lakehouse.demo.sales_order
WITH (
  format = 'PARQUET',
  location = 's3://warehouse/iceberg/demo/sales_order'
)
AS
SELECT
  orderid,
  ordertimestamp,
  customerid,
  customername,
  customeremail,
  customersegment,
  currency,
  lineitemcount
FROM warehouse.landing.sales_order;

DROP TABLE IF EXISTS lakehouse.demo.sales_order_line_item;
CREATE TABLE lakehouse.demo.sales_order_line_item
WITH (
  format = 'PARQUET',
  location = 's3://warehouse/iceberg/demo/sales_order_line_item'
)
AS
SELECT
  orderid,
  ordertimestamp,
  customerid,
  customername,
  lineitemid,
  sku,
  productname,
  quantity,
  currency
FROM warehouse.landing.sales_order_line_item;

DROP TABLE IF EXISTS lakehouse.demo.customer_sales;
CREATE TABLE lakehouse.demo.customer_sales
WITH (
  format = 'PARQUET',
  location = 's3://warehouse/iceberg/demo/customer_sales'
)
AS
SELECT
  customerid,
  customername,
  customeremail,
  customersegment,
  ordercount,
  lastorderid,
  updatedat,
  currency
FROM warehouse.landing.customer_sales;
