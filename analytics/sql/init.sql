create schema if not exists landing;
create schema if not exists stage;
create schema if not exists gold;

create table if not exists landing.sales_order (
	orderid text,
	ordertimestamp timestamptz,
	customerid text,
	customername text,
	customeremail text,
	customersegment text,
	currency text,
	ordertotal numeric,
	lineitemcount integer
);

create table if not exists landing.sales_order_line_item (
	orderid text,
	ordertimestamp timestamptz,
	customerid text,
	customername text,
	lineitemid text,
	sku text,
	productname text,
	quantity integer,
	unitprice numeric,
	linetotal numeric,
	currency text
);

create table if not exists landing.customer_sales (
	customerid text,
	customername text,
	customeremail text,
	customersegment text,
	ordercount bigint,
	totalspent numeric,
	lastorderid text,
	updatedat timestamptz,
	currency text
);
