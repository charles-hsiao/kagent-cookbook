# Demo 02: BYO Agent Reusing kagent-Registered MCP Tools

BYO agents can connect directly to the same MCP server.

---

## Core Concept

The kagent `MCPServer` CRD does one important thing:

**It creates a real Kubernetes Service.**

```
MCPServer CRD  →  kagent controller  →  K8s Deployment + K8s Service
                                         ↓
                                 shared-fetch-tools.kagent.svc.cluster.local:3000
```

That Service is a plain Kubernetes Service — any pod in the cluster can connect to it, not just Declarative agents.

---

## Architecture

```
                    ┌─────────────────────────────────────┐
                    │  Kubernetes Cluster (namespace: kagent)│
                    │                                       │
  MCPServer CRD ──▶ │  ┌─────────────────────────┐         │
  (shared-fetch-    │  │  MCP Server Pod          │         │
   tools)           │  │  (uvx mcp-server-fetch)  │         │
                    │  └────────────┬────────────┘         │
                    │               │ K8s Service           │
                    │   shared-fetch-tools:3000             │
                    │               │                       │
                    │    ┌──────────┴──────────┐            │
                    │    ▼                     ▼            │
                    │  ┌──────────────┐ ┌──────────────┐   │
                    │  │ Declarative  │ │  BYO Agent   │   │
                    │  │ Agent        │ │  Pod         │   │
                    │  │ (via kagent) │ │ (direct DNS) │   │
                    │  └──────────────┘ └──────────────┘   │
                    └─────────────────────────────────────┘

  Both agent types use the same MCP server — identical tool behavior.
```

---

## Directory Structure

```
demo-02-tool-reuse/
├── agent/
│   ├── agent.py          # BYO agent, connects directly to MCP server
│   ├── Dockerfile
│   └── pyproject.toml
├── tools/
│   ├── server.py         # Custom MCP tool server
│   ├── Dockerfile
│   └── pyproject.toml
└── k8s/
    ├── mcp-server.yaml   # Defines the shared MCPServer CRD
    └── byo-agent.yaml    # BYO Agent CRD, injects MCP_SERVER_URL
```

---

## Deployment Steps

### 1. Deploy the shared MCP server

```bash
kubectl apply -f k8s/mcp-server.yaml

# Verify the Service was created
kubectl get svc -n kagent shared-fetch-tools
# NAME                TYPE        CLUSTER-IP    PORT(S)    AGE
# shared-fetch-tools  ClusterIP   10.96.x.x     3000/TCP   30s
```

### 2. Build and push the BYO agent container

```bash
docker build -t ghcr.io/YOUR_ORG/byo-mcp-agent:latest ./agent
docker push ghcr.io/YOUR_ORG/byo-mcp-agent:latest
```

### 3. Update and deploy the BYO agent

```bash
# Edit the image field in k8s/byo-agent.yaml, then:
kubectl apply -f k8s/byo-agent.yaml
```

### 4. Verify the connection

```bash
# Test MCP server connectivity from inside the BYO agent pod
kubectl exec -n kagent -it deploy/byo-agent-with-shared-tools -- \
  curl http://shared-fetch-tools.kagent.svc.cluster.local:3000/sse
```

---

## Code Highlights

```python
# Core of agent.py

MCP_SERVER_URL = os.environ.get(
    "MCP_SERVER_URL",
    "http://shared-utils.kagent.svc.cluster.local:3000"
)
#                     ↑                 ↑             ↑
#               Service name        Namespace       Port
#          (from MCPServer CRD metadata.name)

root_agent = Agent(
    tools=[
        MCPToolset(
            connection_params=SseServerParams(
                url=f"{MCP_SERVER_URL}/sse"  # SSE endpoint
            )
        )
    ],
)
```

`MCP_SERVER_URL` is injected via environment variable, making it easy to switch between environments (dev/staging/prod) and keeping `k8s/byo-agent.yaml` as the single source of configuration.

---

## Advanced: Declarative Agent as a BYO Agent Tool

In addition to connecting directly to an MCP server, a BYO agent can also use another kagent Agent as a tool (Agent-as-Tool pattern):

```python
from google.adk.agents.agent_tools import agent_tool

# Suppose you have a Declarative agent that handles database queries.
# Wrap it as a tool via A2A.
db_query_tool = agent_tool.AgentTool(agent=db_query_agent)

root_agent = Agent(
    tools=[db_query_tool, ...],
)
```

This lets you combine the convenience of Declarative agents (no runtime to manage) with the flexibility of BYO agents.
