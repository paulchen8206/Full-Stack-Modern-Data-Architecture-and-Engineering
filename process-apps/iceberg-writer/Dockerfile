FROM ghcr.io/astral-sh/uv:python3.11-bookworm-slim

WORKDIR /app

# Install build tools, librdkafka-dev, pkg-config, and python3-dev for confluent-kafka
RUN apt-get update && apt-get install -y --no-install-recommends build-essential gcc libc-dev librdkafka-dev pkg-config python3-dev netcat-openbsd && rm -rf /var/lib/apt/lists/*

COPY pyproject.toml ./
COPY app ./app
RUN uv sync --no-dev

COPY wait-for-it.sh /usr/local/bin/wait-for-it.sh
RUN chmod +x /usr/local/bin/wait-for-it.sh

# Wait for warehouse Postgres before starting iceberg-writer
CMD ["/usr/local/bin/wait-for-it.sh", "snowflake-mimic:5432", "uv", "run", "iceberg-writer"]
