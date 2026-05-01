import os
import random
import time
from datetime import date, datetime, timedelta
from decimal import Decimal, ROUND_HALF_UP

import mysql.connector
from mysql.connector import Error

MYSQL_HOST = os.environ.get("MYSQL_HOST", "127.0.0.1")
MYSQL_PORT = int(os.environ.get("MYSQL_PORT", 3306))
MYSQL_USER = os.environ.get("MYSQL_USER", "root")
MYSQL_PASSWORD = os.environ.get("MYSQL_PASSWORD", "mdmroot")
MYSQL_DATABASE = os.environ.get("MYSQL_DATABASE", "mdm")
INTERVAL_SEC = int(os.environ.get("MDM_SOURCE_INTERVAL_SEC", "180"))
APP_MYSQL_USER = os.environ.get("MDM_APP_MYSQL_USER", "mdm")
APP_MYSQL_PASSWORD = os.environ.get("MDM_APP_MYSQL_PASSWORD", "mdm")
INSERT_NEW_KEY_PROB = float(os.environ.get("MDM_INSERT_NEW_KEY_PROB", "0.8"))

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


def money(value: Decimal) -> Decimal:
    return value.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)

def get_connection():
    return mysql.connector.connect(
        host=MYSQL_HOST,
        port=MYSQL_PORT,
        user=MYSQL_USER,
        password=MYSQL_PASSWORD,
        database=MYSQL_DATABASE,
        autocommit=False,
    )


def ensure_app_user() -> None:
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "CREATE USER IF NOT EXISTS %s@'%%' IDENTIFIED BY %s",
            (APP_MYSQL_USER, APP_MYSQL_PASSWORD),
        )
        cursor.execute(
            "GRANT ALL PRIVILEGES ON mdm.* TO %s@'%%'",
            (APP_MYSQL_USER,),
        )
        cursor.execute("FLUSH PRIVILEGES")
        conn.commit()
        print(f"Ensured MySQL app user {APP_MYSQL_USER}@%.", flush=True)
    finally:
        cursor.close()
        conn.close()


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
    # Most cycles use a random day to grow mdm_date; some keep today's key.
    if random.random() < INSERT_NEW_KEY_PROB:
        return (now - timedelta(days=random.randint(0, 730))).date()
    return now.date()


def insert_random_data():
    conn = get_connection()
    cursor = conn.cursor()
    try:
        customer_id, customer_name, customer_email = customer_seed()
        product_id, product_name = product_seed()
        now = datetime.utcnow()
        target_date = date_seed(now)
        first_order_timestamp = now - timedelta(days=random.randint(30, 180))
        first_seen_at = now - timedelta(days=random.randint(30, 365))
        orders_count = random.randint(1, 120)
        units_sold = random.randint(1, 300)
        avg_unit_price = money(Decimal(str(random.uniform(10, 500))))
        projected_total_spent = money(avg_unit_price * orders_count)

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
                customer_name,
                customer_email,
                random.choice(SEGMENTS),
                "USD",
                first_order_timestamp,
                now,
                orders_count,
                str(projected_total_spent),
                now,
            ),
        )

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
                first_seen_at,
                now,
                orders_count,
                units_sold,
                str(avg_unit_price),
            ),
        )

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

        conn.commit()
        print(f"Generated changes for {customer_id}, {product_id}, and mdm_date.", flush=True)
    finally:
        cursor.close()
        conn.close()


def main():
    app_user_ready = False
    while True:
        try:
            if not app_user_ready:
                ensure_app_user()
                app_user_ready = True
            insert_random_data()
            time.sleep(INTERVAL_SEC)
        except Error as exc:
            print(f"MySQL not ready, retrying: {exc}", flush=True)
            time.sleep(2)

if __name__ == "__main__":
    main()
