import os
import time

from pyspark.sql import SparkSession


def env(name: str, default: str) -> str:
    return os.getenv(name, default)


def read_mysql_table(spark: SparkSession, jdbc_url: str, table: str, user: str, password: str):
    return (
        spark.read.format("jdbc")
        .option("url", jdbc_url)
        .option("driver", "com.mysql.cj.jdbc.Driver")
        .option("dbtable", table)
        .option("user", user)
        .option("password", password)
        .load()
    )


def write_postgres_table(df, jdbc_url: str, table: str, user: str, password: str) -> None:
    (
        df.write.format("jdbc")
        .mode("overwrite")
        .option("truncate", "true")
        .option("url", jdbc_url)
        .option("driver", "org.postgresql.Driver")
        .option("dbtable", table)
        .option("user", user)
        .option("password", password)
        .save()
    )


def main() -> None:
    mysql_host = env("MDM_MYSQL_HOST", "mysql-mdm")
    mysql_port = env("MDM_MYSQL_PORT", "3306")
    mysql_db = env("MDM_MYSQL_DB", "mdm")
    mysql_user = env("MDM_MYSQL_USER", "root")
    mysql_password = env("MDM_MYSQL_PASSWORD", "mdmroot")

    pg_host = env("POSTGRES_HOST", "postgres")
    pg_port = env("POSTGRES_PORT", "5432")
    pg_db = env("POSTGRES_DB", "analytics")
    pg_user = env("POSTGRES_USER", "analytics")
    pg_password = env("POSTGRES_PASSWORD", "analytics")

    sync_interval_sec = int(env("MDM_SYNC_INTERVAL_SEC", "15"))

    mysql_jdbc_url = (
        f"jdbc:mysql://{mysql_host}:{mysql_port}/{mysql_db}"
        "?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC"
    )
    pg_jdbc_url = f"jdbc:postgresql://{pg_host}:{pg_port}/{pg_db}"

    table_map = {
        "customer360": "landing.mdm_customer360",
        "product_master": "landing.mdm_product_master",
        "mdm_date": "landing.mdm_date",
    }

    spark = SparkSession.builder.appName("mdm-mysql-to-postgres-landing-sync").getOrCreate()

    print("mdm pyspark sync started", flush=True)

    while True:
        try:
            for mysql_table, pg_table in table_map.items():
                df = read_mysql_table(
                    spark=spark,
                    jdbc_url=mysql_jdbc_url,
                    table=mysql_table,
                    user=mysql_user,
                    password=mysql_password,
                )
                row_count = df.count()
                write_postgres_table(
                    df=df,
                    jdbc_url=pg_jdbc_url,
                    table=pg_table,
                    user=pg_user,
                    password=pg_password,
                )
                print(
                    f"synced {row_count} rows from mysql.{mysql_table} to {pg_table}",
                    flush=True,
                )
        except Exception as exc:
            print(f"sync cycle failed: {exc}", flush=True)

        time.sleep(sync_interval_sec)


if __name__ == "__main__":
    main()
