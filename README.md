# kagent BYO Agent Demo

End-to-end examples showing what you can build with kagent's BYO Agent mode — full ADK control and shared MCP tool reuse.

---

## Declarative vs BYO Agent

kagent offers two agent types:

| Feature | Declarative Agent | BYO Agent |
|---------|-------------------|-----------|
| Runtime | Managed by kagent | Your own container |
| ADK config | kagent-supported params only | 100% free |
| Tool connection | Declared via `spec.tools` | Wired in code |
| Getting started | Easy (YAML only) | Moderate (container required) |
| Use case | Standard tool combinations | Custom ADK behavior |

**How BYO Agent works:**
1. You package a container that implements the A2A protocol and listens on port 8080
2. Use the `kagent-adk` CLI (`pip install kagent-adk`) to automatically wrap an ADK agent as an A2A server — no HTTP code needed
3. kagent deploys the container as a K8s Deployment and proxies `/api/a2a/{namespace}/{agent-name}/...`

---

## Use Cases

### Use Case 1: Full ADK Control

BYO agents let you write ADK code directly, unlocking features unavailable in Declarative agents:

- `BuiltInPlanner` and `ThinkingConfig`
- Any feature from any ADK version
- Custom before/after callbacks
- Composing multiple sub-agents

See [demo-01-byo-full-control](./demo-01-byo-full-control/)

---

### Use Case 2: Reusing Shared MCP Tools

The kagent `MCPServer` CRD creates a real Kubernetes Service. Any pod in the cluster can connect to it directly via DNS — including BYO agents:

```
http://<mcp-server-name>.<namespace>.svc.cluster.local:<port>
```

A BYO agent connects to this URL using `MCPToolset`, accessing the same tools as Declarative agents without routing through kagent's tool system.

See [demo-02-tool-reuse](./demo-02-tool-reuse/)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                  Kubernetes Cluster                  │
│                                                      │
│  ┌──────────────┐    ┌──────────────────────────┐   │
│  │ kagent       │    │ MCPServer CRD            │   │
│  │ Controller   │───▶│ → K8s Deployment + Svc   │   │
│  └──────────────┘    │   (e.g. fetch, k8s-tools)│   │
│         │            └──────────┬───────────────┘   │
│         │                       │ cluster DNS        │
│         ▼                       ▼                    │
│  ┌──────────────┐    ┌──────────────────────────┐   │
│  │ Declarative  │    │ BYO Agent Pod            │   │
│  │ Agent Pod    │    │ (your container)         │   │
│  │ (kagent mgd) │    │ - full ADK control       │   │
│  └──────────────┘    │ - direct MCP connection  │   │
│                      └──────────────────────────┘   │
│                                                      │
│  kagent API proxy: /api/a2a/{ns}/{agent-name}/...   │
└─────────────────────────────────────────────────────┘
```

---

## Quick Start

Each demo folder has its own README. Recommended reading order:

1. **[demo-01-byo-full-control](./demo-01-byo-full-control/)** — Full ADK control with a BYO agent
2. **[demo-02-tool-reuse](./demo-02-tool-reuse/)** — BYO agent reusing kagent MCP tools

### Prerequisites

- [`kind`](https://kind.sigs.k8s.io/) — local Kubernetes cluster
- `kubectl`, `helm`, `docker`

### Deploy to kind (local)

```bash
# 1. Create a kind cluster and install kagent (run once)
export GOOGLE_API_KEY=<your-google-api-key>
./scripts/kind-setup.sh

# 2a. Deploy demo-01 (BYO agent with BuiltInPlanner)
./demo-01-byo-full-control/deploy-kind.sh

# 2b. Deploy demo-02 (BYO agent reusing shared MCP tools)
./demo-02-tool-reuse/deploy-kind.sh
```

The kagent UI is available at **http://localhost:8080** after setup.

---

## Further Reading

- [kagent documentation](https://kagent.dev/docs)
- [A2A Protocol](https://google.github.io/A2A/)
- [Google ADK](https://google.github.io/adk-docs/)
- [kagent-adk CLI](https://pypi.org/project/kagent-adk/)
