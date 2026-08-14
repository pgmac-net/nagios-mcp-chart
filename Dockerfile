FROM python:3.12-slim AS builder

WORKDIR /app

COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

ENV UV_SYSTEM_PYTHON=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy

# Needed to install from a git ref; not present in python:3.12-slim.
RUN apt-get update \
    && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/*

# Built from the pgmac-net fork rather than the PyPI release. The published
# package advertises its SSE POST endpoint as "/messages" while mounting
# "/messages", so Starlette 307-redirects every POST. That extra hop sits on
# the initialize handshake, and since each GET /sse mints a new session, a
# client can end up on a session that never completed initialize -- every
# tool call then fails with JSON-RPC -32602 until the client reconnects.
# The fork also caps mcp below 2.0, which dropped the decorator API this
# server uses and breaks it at import time.
# See https://github.com/pgmac-net/nagios-mcp/pull/2
ARG NAGIOS_MCP_REF=1f4696f4e629ea31fae433126173e0249b81bf4c
RUN uv pip install --no-cache \
    "nagios-mcp @ git+https://github.com/pgmac-net/nagios-mcp.git@${NAGIOS_MCP_REF}"

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

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python3 -c "import socket; socket.create_connection(('localhost', 8000), timeout=3).close()" || exit 1

CMD ["nagios-mcp", "--config", "/config/nagios_config.yaml", "--transport", "sse", "--host", "0.0.0.0", "--port", "8000"]
