# nagios-mcp-chart

Docker image and Helm chart for [nagios-mcp](https://github.com/PROSPIRE-TECHNOLOGY-SERVICES/nagios-mcp) — an MCP server for Nagios monitoring — deployed on pvek8s in SSE transport mode.

The image is built from the [pgmac-net fork](https://github.com/pgmac-net/nagios-mcp) rather than the PyPI release, pinned to a commit via the `NAGIOS_MCP_REF` build arg in the Dockerfile. See [Why the fork](#why-the-fork).

## What it does

Packages the upstream `nagios-mcp` Python package into a container and deploys it to the `observability` namespace at `nagios-mcp.int.pgmac.net`. Claude Code connects to it via SSE MCP transport to query Nagios host/service status, alerts, downtimes, and health summaries.

## Pre-requisites

Create the config Secret in the `observability` namespace before ArgoCD syncs:

```bash
kubectl -n observability create secret generic nagios-mcp-config \
  --from-literal=nagios_config.yaml="$(cat <<'EOF'
nagios_url: https://nagios.int.pgmac.net
nagios_user: <user>
nagios_pass: <pass>
ca_cert_path: 
EOF
)"
```

Note: `ca_cert_path` is required. An empty value is acceptable.

If Nagios uses a self-signed CA, add the cert as an additional key:

```bash
kubectl -n observability create secret generic nagios-mcp-config \
  --from-literal=nagios_config.yaml="$(cat <<'EOF'
nagios_url: https://nagios.int.pgmac.net
nagios_user: <user>
nagios_pass: <pass>
ca_cert_path: /config/ca.crt
EOF
)" \
  --from-file=ca.crt=/path/to/ca.crt
```

## Helm chart

```bash
helm lint helm/nagios-mcp
helm template nagios-mcp helm/nagios-mcp
```

## MCP client configuration

Add to Claude Code settings (`~/.claude/settings.json`):

```json
{
  "mcpServers": {
    "nagios": {
      "type": "sse",
      "url": "http://nagios-mcp.int.pgmac.net/sse"
    }
  }
}
```

## Docker image

Built and pushed to `macro.int.pgmac.net:5000/nagios-mcp` on every push to `main` via GitHub Actions (Trivy scan → BuildKit on pvek8s → CalVer tags).

## Why the fork

The image installs `nagios-mcp` from `git+https://github.com/pgmac-net/nagios-mcp.git` at the commit pinned in `NAGIOS_MCP_REF`, instead of the PyPI release. Two defects in the published package make it unusable here:

**Every POST to the SSE messages endpoint gets a 307.** The server advertises its POST endpoint as `/messages` but mounts the receiving route at `/messages`, and Starlette's `Mount` treats its path as a prefix — so it redirects to `/messages/`. Clients that replay the body on redirect recover, so this mostly looks harmless. But the extra hop sits on the `initialize` handshake, and each `GET /sse` mints a *new* server-side session. A client can end up holding a session that never completed `initialize`, after which every tool call is rejected with JSON-RPC `-32602 Invalid request parameters` until the MCP client is reconnected. Seen in practice as "the Nagios MCP is running but I have to reconnect to use it".

**`mcp` was not capped below 2.0.** `mcp` 2.0.0 removed the decorator API this server is built on, so any fresh install fails at import with `AttributeError: 'Server' object has no attribute 'list_tools'`.

Both are fixed in [pgmac-net/nagios-mcp#2](https://github.com/pgmac-net/nagios-mcp/pull/2). To pick up later fork changes, bump `NAGIOS_MCP_REF` in the `Dockerfile`.
