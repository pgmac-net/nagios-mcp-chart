# nagios-mcp-chart

Docker image and Helm chart for [nagios-mcp](https://github.com/PROSPIRE-TECHNOLOGY-SERVICES/nagios-mcp) — an MCP server for Nagios monitoring — deployed on pvek8s in SSE transport mode.

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
EOF
)"
```

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
