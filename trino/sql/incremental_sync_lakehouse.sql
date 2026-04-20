CREATE SCHEMA IF NOT EXISTS lakehouse.demo
WITH (location = 's3://warehouse/iceberg/demo');

CREATE TABLE IF NOT EXISTS lakehouse.demo.sales_order
WITH (
  format = 'PARQUET',
  location = 's3://warehouse/iceberg/demo/sales_order'
)
AS
SELECT *
FROM warehouse.landing.sales_order
WHERE 1 = 0;

CREATE TABLE IF NOT EXISTS lakehouse.demo.sales_order_line_item
WITH (
  format = 'PARQUET',
  location = 's3://warehouse/iceberg/demo/sales_order_line_item'
)
AS
SELECT *
FROM warehouse.landing.sales_order_line_item
WHERE 1 = 0;

CREATE TABLE IF NOT EXISTS lakehouse.demo.customer_sales
WITH (
  format = 'PARQUET',
  location = 's3://warehouse/iceberg/demo/customer_sales'
)
AS
SELECT *
FROM warehouse.landing.customer_sales
WHERE 1 = 0;

MERGE INTO lakehouse.demo.sales_order AS target
USING warehouse.landing.sales_order AS source
ON target.orderid = source.orderid
WHEN MATCHED THEN UPDATE SET
  ordertimestamp = source.ordertimestamp,
  customerid = source.customerid,
  customername = source.customername,
  customeremail = source.customeremail,
  customersegment = source.customersegment,
  currency = source.currency,
  lineitemcount = source.lineitemcount
WHEN NOT MATCHED THEN INSERT (
  orderid, ordertimestamp, customerid, customername, customeremail,
  customersegment, currency, lineitemcount
) VALUES (
  source.orderid, source.ordertimestamp, source.customerid, source.customername, source.customeremail,
  source.customersegment, source.currency, source.lineitemcount
);

MERGE INTO lakehouse.demo.sales_order_line_item AS target
USING warehouse.landing.sales_order_line_item AS source
ON target.lineitemid = source.lineitemid
WHEN MATCHED THEN UPDATE SET
  orderid = source.orderid,
  ordertimestamp = source.ordertimestamp,
  customerid = source.customerid,
  customername = source.customername,
  sku = source.sku,
  productname = source.productname,
  quantity = source.quantity,
  currency = source.currency
WHEN NOT MATCHED THEN INSERT (
  orderid, ordertimestamp, customerid, customername, lineitemid,
  sku, productname, quantity, currency
) VALUES (
  source.orderid, source.ordertimestamp, source.customerid, source.customername, source.lineitemid,
  source.sku, source.productname, source.quantity, source.currency
);

MERGE INTO lakehouse.demo.customer_sales AS target
USING warehouse.landing.customer_sales AS source
ON target.customerid = source.customerid
WHEN MATCHED THEN UPDATE SET
  customername = source.customername,
  customeremail = source.customeremail,
  customersegment = source.customersegment,
  ordercount = source.ordercount,
  lastorderid = source.lastorderid,
  updatedat = source.updatedat,
  currency = source.currency
WHEN NOT MATCHED THEN INSERT (
  customerid, customername, customeremail, customersegment,
  ordercount, lastorderid, updatedat, currency
) VALUES (
  source.customerid, source.customername, source.customeremail, source.customersegment,
  source.ordercount, source.lastorderid, source.updatedat, source.currency
);