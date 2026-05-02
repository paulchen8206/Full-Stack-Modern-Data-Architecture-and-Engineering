#!/usr/bin/env python3

import argparse
import json
import sys
import urllib.error
import urllib.request


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run SQL against a Trino coordinator over HTTP.")
    parser.add_argument("--server", default="http://localhost:8086", help="Trino coordinator URL")
    parser.add_argument("--user", default="analytics", help="Trino user header")
    parser.add_argument("--catalog", help="Default Trino catalog")
    parser.add_argument("--schema", help="Default Trino schema")
    parser.add_argument("--sql", help="Inline SQL to execute")
    parser.add_argument("--file", help="Path to SQL file to execute")
    parser.add_argument("--output", choices=["table", "json"], default="table", help="Output format")
    return parser.parse_args()


def load_sql(args: argparse.Namespace) -> str:
    if args.sql and args.file:
        raise SystemExit("Use either --sql or --file, not both.")
    if args.file:
        with open(args.file, "r", encoding="utf-8") as handle:
            return handle.read()
    if args.sql:
        return args.sql
    return sys.stdin.read()


def split_statements(sql: str) -> list[str]:
    statements: list[str] = []
    buffer: list[str] = []
    in_single_quote = False
    in_double_quote = False

    index = 0
    while index < len(sql):
        char = sql[index]
        if char == "'" and not in_double_quote:
            if in_single_quote and index + 1 < len(sql) and sql[index + 1] == "'":
                buffer.append("''")
                index += 2
                continue
            in_single_quote = not in_single_quote
        elif char == '"' and not in_single_quote:
            in_double_quote = not in_double_quote
        elif char == ";" and not in_single_quote and not in_double_quote:
            statement = "".join(buffer).strip()
            if statement:
                statements.append(statement)
            buffer = []
            index += 1
            continue

        buffer.append(char)
        index += 1

    trailing = "".join(buffer).strip()
    if trailing:
        statements.append(trailing)
    return statements


def build_request(url: str, sql: str, args: argparse.Namespace) -> urllib.request.Request:
    request = urllib.request.Request(
        url=f"{url.rstrip('/')}/v1/statement",
        data=sql.encode("utf-8"),
        method="POST",
    )
    request.add_header("X-Trino-User", args.user)
    if args.catalog:
        request.add_header("X-Trino-Catalog", args.catalog)
    if args.schema:
        request.add_header("X-Trino-Schema", args.schema)
    return request


def fetch_json(request_or_url):
    if isinstance(request_or_url, str):
      target = urllib.request.Request(request_or_url, method="GET")
    else:
      target = request_or_url
    try:
        with urllib.request.urlopen(target) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        message = error.read().decode("utf-8", errors="replace")
        raise SystemExit(f"Trino HTTP error {error.code}: {message}") from error
    except urllib.error.URLError as error:
        raise SystemExit(f"Unable to reach Trino: {error}") from error


def render_table(columns, rows):
    headers = [column["name"] for column in columns] if columns else []
    if not headers:
        return
    widths = [len(header) for header in headers]
    formatted_rows = []
    for row in rows:
        formatted = ["" if value is None else str(value) for value in row]
        formatted_rows.append(formatted)
        for index, value in enumerate(formatted):
            widths[index] = max(widths[index], len(value))
    line = " | ".join(header.ljust(widths[index]) for index, header in enumerate(headers))
    separator = "-+-".join("-" * widths[index] for index in range(len(widths)))
    print(line)
    print(separator)
    for row in formatted_rows:
        print(" | ".join(value.ljust(widths[index]) for index, value in enumerate(row)))


def main() -> None:
    args = parse_args()
    sql = load_sql(args).strip()
    if not sql:
        raise SystemExit("No SQL provided.")

    statements = split_statements(sql)
    final_columns = None
    final_rows = []

    for statement in statements:
        result = fetch_json(build_request(args.server, statement, args))
        rows = []
        columns = result.get("columns")

        while True:
            if "error" in result:
                error = result["error"]
                raise SystemExit(f"Trino query failed: {error.get('message', 'unknown error')}")
            rows.extend(result.get("data", []))
            next_uri = result.get("nextUri")
            if not next_uri:
                break
            result = fetch_json(next_uri)
            if not columns and result.get("columns"):
                columns = result["columns"]

        final_columns = columns
        final_rows = rows

    if args.output == "json":
        print(json.dumps({"columns": final_columns or [], "data": final_rows}, indent=2))
        return

    if final_columns:
        render_table(final_columns, final_rows)
    else:
        print("Query completed.")


if __name__ == "__main__":
    main()
