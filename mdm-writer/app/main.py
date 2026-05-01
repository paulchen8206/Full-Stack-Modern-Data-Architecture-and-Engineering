import os
import random
import time
from datetime import date, datetime, timedelta
from decimal import Decimal, ROUND_HALF_UP

import mysql.connector


SEGMENTS = ["SMB", "MID_MARKET", "ENTERPRISE"]
CUSTOMERS = [
    ("CUST-1001", "Ava Chen", "ava.chen@example.com"),
    ("CUST-1002", "Liam Patel", "liam.patel@example.com"),
    ("CUST-1003", "Sophia Nguyen", "sophia.nguyen@example.com"),
    ("CUST-1004", "Noah Brown", "noah.brown@example.com"),
]
PRODUCTS = [
    ("SKU-100", "Wireless Mouse"),
    ("SKU-101", "Mechanical Keyboard"),
    ("SKU-102", "4K Monitor"),
    ("SKU-103", "USB-C Dock"),
    ("SKU-104", "Noise Cancelling Headset"),
]
INSERT_NEW_KEY_PROB = float(os.getenv("MDM_INSERT_NEW_KEY_PROB", "0.8"))


def money(value: Decimal) -> Decimal:
    return value.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def mysql_connection() -> mysql.connector.MySQLConnection:
    return mysql.connector.connect(
        host=os.getenv("MDM_MYSQL_HOST", "mysql-mdm"),
        port=int(os.getenv("MDM_MYSQL_PORT", "3306")),
        user=os.getenv("MDM_MYSQL_USER", "root"),
        password=os.getenv("MDM_MYSQL_PASSWORD", "mdmroot"),
        database=os.getenv("MDM_MYSQL_DB", "mdm"),
        autocommit=False,
    )


def customer_seed() -> tuple[str, str, str]:
    if random.random() < INSERT_NEW_KEY_PROB:
        customer_num = random.randint(1000, 999999)
        return (
            f"CUST-{customer_num}",
            f"Customer {customer_num}",
            f"customer{customer_num}@example.com",
        )
    return random.choice(CUSTOMERS)


def product_seed() -> tuple[str, str]:
    if random.random() < INSERT_NEW_KEY_PROB:
        product_num = random.randint(100, 999999)
        return (f"SKU-{product_num}", f"Product {product_num}")
    return random.choice(PRODUCTS)


def date_seed(now: datetime) -> date:
    if random.random() < INSERT_NEW_KEY_PROB:
        return (now - timedelta(days=random.randint(0, 730))).date()
    return now.date()


def upsert_customer(cursor: mysql.connector.cursor.MySQLCursor) -> None:
    customer_id, name, email = customer_seed()
    now = datetime.utcnow()
    first_seen = now - timedelta(days=random.randint(7, 180))
    last_seen = now - timedelta(days=random.randint(0, 7))
    projected_order_count = random.randint(1, 40)
    projected_total_spent = money(Decimal(str(random.uniform(100, 10000))))

    cursor.execute(
        """
        INSERT INTO customer360 (
          customer_id,
          customer_name,
          customer_email,
          customer_segment,
          currency,
          first_order_timestamp,
          last_order_timestamp,
          projected_order_count,
          projected_total_spent,
          projection_updated_at
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        ON DUPLICATE KEY UPDATE
          customer_name = VALUES(customer_name),
          customer_email = VALUES(customer_email),
          customer_segment = VALUES(customer_segment),
          currency = VALUES(currency),
          first_order_timestamp = VALUES(first_order_timestamp),
          last_order_timestamp = VALUES(last_order_timestamp),
          projected_order_count = VALUES(projected_order_count),
          projected_total_spent = VALUES(projected_total_spent),
          projection_updated_at = VALUES(projection_updated_at)
        """,
        (
            customer_id,
            name,
            email,
            random.choice(SEGMENTS),
            "USD",
            first_seen,
            last_seen,
            projected_order_count,
            str(projected_total_spent),
            now,
        ),
    )


def upsert_product(cursor: mysql.connector.cursor.MySQLCursor) -> None:
    product_id, product_name = product_seed()
    now = datetime.utcnow()
    first_seen = now - timedelta(days=random.randint(14, 365))
    last_seen = now - timedelta(days=random.randint(0, 14))
    orders_count = random.randint(5, 200)
    units_sold = random.randint(orders_count, orders_count * 5)
    avg_unit_price = money(Decimal(str(random.uniform(10, 600))))

    cursor.execute(
        """
        INSERT INTO product_master (
          product_id,
          product_name,
          currency,
          first_seen_at,
          last_seen_at,
          orders_count,
          units_sold,
          avg_unit_price
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        ON DUPLICATE KEY UPDATE
          product_name = VALUES(product_name),
          currency = VALUES(currency),
          first_seen_at = VALUES(first_seen_at),
          last_seen_at = VALUES(last_seen_at),
          orders_count = VALUES(orders_count),
          units_sold = VALUES(units_sold),
          avg_unit_price = VALUES(avg_unit_price)
        """,
        (
            product_id,
            product_name,
            "USD",
            first_seen,
            last_seen,
            orders_count,
            units_sold,
            str(avg_unit_price),
        ),
    )


def upsert_date(cursor: mysql.connector.cursor.MySQLCursor) -> None:
        now = datetime.utcnow()
        target_date = date_seed(now)

        cursor.execute(
                """
                INSERT INTO mdm_date (
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
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON DUPLICATE KEY UPDATE
                    updated_at = CURRENT_TIMESTAMP
                """,
                (
                        int(target_date.strftime("%Y%m%d")),
                        target_date,
                        target_date.day,
                        ((target_date.isoweekday() % 7) + 1),
                        target_date.strftime("%A"),
                        int(target_date.strftime("%V")),
                        target_date.month,
                        target_date.strftime("%B"),
                        ((target_date.month - 1) // 3) + 1,
                        target_date.year,
                        target_date.weekday() >= 5,
                ),
        )


def main() -> None:
    interval_ms = int(os.getenv("MDM_WRITE_INTERVAL_MS", "3000"))

    while True:
        try:
            conn = mysql_connection()
            cursor = conn.cursor()
            upsert_customer(cursor)
            upsert_product(cursor)
            upsert_date(cursor)
            conn.commit()
            cursor.close()
            conn.close()
            print("upserted customer360, product_master, and mdm_date rows", flush=True)
            time.sleep(interval_ms / 1000)
        except mysql.connector.Error as exc:
            print(f"mysql unavailable, retrying: {exc}", flush=True)
            time.sleep(2)


if __name__ == "__main__":
    main()
