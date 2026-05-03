FROM ghcr.io/astral-sh/uv:python3.11-bookworm-slim

WORKDIR /app

COPY pyproject.toml ./
COPY app ./app
RUN uv sync --no-dev

CMD ["uv", "run", "mdm-cdc-curate"]
