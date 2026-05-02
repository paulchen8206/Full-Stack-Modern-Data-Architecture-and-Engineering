CREATE DATABASE IF NOT EXISTS mdm;

USE mdm;

CREATE TABLE IF NOT EXISTS customer360 (
  customer_id VARCHAR(64) PRIMARY KEY,
  customer_name VARCHAR(255) NOT NULL,
  customer_email VARCHAR(255) NOT NULL,
  customer_segment VARCHAR(64) NOT NULL,
  currency VARCHAR(8) NOT NULL DEFAULT 'USD',
  first_order_timestamp DATETIME NULL,
  last_order_timestamp DATETIME NULL,
  projected_order_count INT NOT NULL DEFAULT 0,
  projected_total_spent DECIMAL(18,2) NOT NULL DEFAULT 0.00,
  projection_updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS product_master (
  product_id VARCHAR(64) PRIMARY KEY,
  product_name VARCHAR(255) NOT NULL,
  currency VARCHAR(8) NOT NULL DEFAULT 'USD',
  first_seen_at DATETIME NULL,
  last_seen_at DATETIME NULL,
  orders_count INT NOT NULL DEFAULT 0,
  units_sold INT NOT NULL DEFAULT 0,
  avg_unit_price DECIMAL(18,2) NOT NULL DEFAULT 0.00,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS mdm_date (
  date_key INT PRIMARY KEY,
  full_date DATE NOT NULL,
  day_of_month TINYINT NOT NULL,
  day_of_week TINYINT NOT NULL,
  day_name VARCHAR(16) NOT NULL,
  week_of_year TINYINT NOT NULL,
  month_of_year TINYINT NOT NULL,
  month_name VARCHAR(16) NOT NULL,
  quarter_of_year TINYINT NOT NULL,
  year_number SMALLINT NOT NULL,
  is_weekend BOOLEAN NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_mdm_date_full_date (full_date)
);

INSERT IGNORE INTO customer360 (
  customer_id,
  customer_name,
  customer_email,
  customer_segment,
  currency,
  first_order_timestamp,
  last_order_timestamp,
  projected_order_count,
  projected_total_spent
) VALUES
  ('CUST-1001', 'Ava Chen', 'ava.chen@example.com', 'MID_MARKET', 'USD', '2026-01-15 09:30:00', '2026-04-16 17:20:00', 18, 3250.50),
  ('CUST-1002', 'Liam Patel', 'liam.patel@example.com', 'SMB', 'USD', '2026-02-03 11:10:00', '2026-04-14 10:05:00', 9, 980.75),
  ('CUST-1003', 'Sophia Nguyen', 'sophia.nguyen@example.com', 'ENTERPRISE', 'USD', '2026-01-28 14:40:00', '2026-04-17 13:30:00', 33, 7890.00),
  ('CUST-1004', 'Noah Brown', 'noah.brown@example.com', 'MID_MARKET', 'USD', '2026-03-12 08:55:00', '2026-04-15 16:45:00', 14, 2425.10);

INSERT IGNORE INTO product_master (
  product_id,
  product_name,
  currency,
  first_seen_at,
  last_seen_at,
  orders_count,
  units_sold,
  avg_unit_price
) VALUES
  ('SKU-100', 'Wireless Mouse', 'USD', '2026-01-05 09:00:00', '2026-04-16 12:10:00', 52, 78, 24.99),
  ('SKU-101', 'Mechanical Keyboard', 'USD', '2026-01-07 09:00:00', '2026-04-16 15:20:00', 61, 74, 89.50),
  ('SKU-102', '4K Monitor', 'USD', '2026-01-10 09:00:00', '2026-04-17 10:40:00', 47, 49, 329.00),
  ('SKU-103', 'USB-C Dock', 'USD', '2026-01-12 09:00:00', '2026-04-17 11:50:00', 39, 46, 159.95),
  ('SKU-104', 'Noise Cancelling Headset', 'USD', '2026-01-15 09:00:00', '2026-04-16 18:30:00', 58, 65, 199.99);

INSERT IGNORE INTO mdm_date (
  date_key,
  full_date,
  day_of_month,
  day_of_week,
  day_name,
  week_of_year,
  month_of_year,
  month_name,
  quarter_of_year,
  year_number,
  is_weekend
) VALUES
  (20260414, '2026-04-14', 14, 3, 'Tuesday', 16, 4, 'April', 2, 2026, false),
  (20260415, '2026-04-15', 15, 4, 'Wednesday', 16, 4, 'April', 2, 2026, false),
  (20260416, '2026-04-16', 16, 5, 'Thursday', 16, 4, 'April', 2, 2026, false),
  (20260417, '2026-04-17', 17, 6, 'Friday', 16, 4, 'April', 2, 2026, false),
  (20260418, '2026-04-18', 18, 7, 'Saturday', 16, 4, 'April', 2, 2026, true),
  (20260419, '2026-04-19', 19, 1, 'Sunday', 16, 4, 'April', 2, 2026, true),
  (20260420, '2026-04-20', 20, 2, 'Monday', 17, 4, 'April', 2, 2026, false);
