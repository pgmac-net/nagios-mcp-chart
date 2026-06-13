FROM python:3.12-slim AS builder

WORKDIR /app

COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

ENV UV_SYSTEM_PYTHON=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy

RUN uv pip install --no-cache nagios-mcp

FROM python:3.12-slim

ARG BUILD_DATE
ARG BUILD_VERSION
ARG VCS_REF

LABEL org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.authors="Paul Macdonnell <pgmac@pgmac.net>" \
      org.opencontainers.image.url="https://github.com/pgmac/nagios-mcp-chart" \
      org.opencontainers.image.documentation="https://github.com/pgmac/nagios-mcp-chart/blob/main/README.md" \
      org.opencontainers.image.source="https://github.com/pgmac/nagios-mcp-chart" \
      org.opencontainers.image.version="${BUILD_VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.vendor="pgmac.net" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.title="Nagios MCP Server" \
      org.opencontainers.image.description="MCP server for Nagios monitoring, running in SSE transport mode"

WORKDIR /app

RUN groupadd -g 10001 nagios && \
    useradd -m -u 10001 -g 10001 nagios && \
    chown -R nagios:nagios /app

COPY --from=builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=builder /usr/local/bin/nagios-mcp /usr/local/bin/nagios-mcp

USER 10001

EXPOSE 8000

CMD ["nagios-mcp", "--config", "/config/nagios_config.yaml", "--transport", "sse", "--host", "0.0.0.0", "--port", "8000"]
