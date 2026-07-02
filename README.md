# kagent Cookbook

A collection of end-to-end examples showcasing what you can build with [kagent](https://kagent.dev) — each demo targets a distinct use case and is self-contained with its own manifests and deployment script.

---

## What is kagent?

[kagent](https://kagent.dev) is a Kubernetes-native agent runtime. It manages AI agents as first-class Kubernetes resources (CRDs), handles routing via the [A2A protocol](https://google.github.io/A2A/), and integrates with MCP tool servers and multiple LLM providers.

### Agent Types

kagent supports two complementary agent models:

| Feature | Declarative Agent | BYO Agent |
|---------|-------------------|-----------|
| Runtime | Managed by kagent | Your own container |
| ADK config | kagent-supported params only | 100% free |
| Tool connection | Declared via `spec.tools` | Wired in code |
| Getting started | Easy (YAML only) | Moderate (container required) |
| Best for | Standard tool combinations | Custom ADK behaviour |

**How BYO Agent works:**
1. Package a container that implements the A2A protocol on port 8080
2. Use `kagent-adk` (`pip install kagent-adk`) to wrap an ADK agent as an A2A server — no HTTP boilerplate needed
3. kagent deploys it as a Kubernetes Deployment and proxies `/api/a2a/{namespace}/{agent-name}/…`

---

## Demos

| # | Demo | What it shows |
|---|------|---------------|
| 01 | [demo-01-byo-full-control](./demo-01-byo-full-control/) | Full ADK control — `BuiltInPlanner`, `ThinkingConfig`, custom callbacks |
| 02 | [demo-02-tool-reuse](./demo-02-tool-reuse/) | BYO agent connecting directly to a shared `MCPServer` via cluster DNS |
| 03 | [demo-03-local-llm](./demo-03-local-llm/) | Declarative agent running on a local LLM (Ollama) — no cloud API key |
| 04 | [demo-04-hitl](./demo-04-hitl/) | Declarative agent with `requireApproval` — read ops run freely, write ops pause for human sign-off |

Each demo folder contains a `README.md` with a detailed walkthrough.

---

## Quick Start

### Prerequisites

- [`kind`](https://kind.sigs.k8s.io/) — local Kubernetes cluster
- `kubectl`, `helm`, `docker`

### Deploy to kind (local)

```bash
# 1. Create a kind cluster and install kagent (run once)
export GOOGLE_API_KEY=<your-google-api-key>
./scripts/kind-setup.sh

# 2. Deploy any demo independently
./demo-01-byo-full-control/deploy-kind.sh
./demo-02-tool-reuse/deploy-kind.sh
./demo-03-local-llm/deploy-kind.sh
./demo-04-hitl/deploy-kind.sh
```

The kagent UI is available at **http://localhost:8080** after setup.

---

## Further Reading

- [kagent documentation](https://kagent.dev/docs)
- [A2A Protocol](https://google.github.io/A2A/)
- [Google ADK](https://google.github.io/adk-docs/)
- [kagent-adk CLI](https://pypi.org/project/kagent-adk/)
