# Demo 01: BYO Agent with Full ADK Control

## Problem Addressed

> "I want to use BuiltInPlanner (or other advanced ADK features), but kagent Declarative agents don't support it."

**Answer: Use a BYO agent. You have 100% control over ADK.**

---

## Core Difference

### Declarative Agent (kagent manages the runtime)

```yaml
# You can only set fields supported by the kagent CRD
spec:
  type: Declarative
  modelConfig: default-model-config
  tools:
    - type: MCPServer
      name: fetch-tools
```

Advanced ADK features like `BuiltInPlanner`, `ThinkingConfig`, and custom callbacks cannot be configured via YAML.

### BYO Agent (you manage the runtime)

```python
# agent.py — you write ADK code directly
root_agent = Agent(
    name="custom_adk_agent",
    model="gemini-2.0-flash",
    planner=BuiltInPlanner(           # works!
        thinking_config=ThinkingConfig(
            thinking_budget=1024,
        )
    ),
    tools=[...],
)
```

---

## Directory Structure

```
demo-01-byo-full-control/
├── agent/
│   ├── agent.py          # ADK agent definition (with BuiltInPlanner)
│   ├── Dockerfile        # Package as a container
│   └── pyproject.toml    # Python dependencies
└── k8s/
    └── agent.yaml        # kagent Agent CRD (type: BYO)
```

---

## Deployment Steps

### 1. Test the agent locally

```bash
cd demo-01-byo-full-control/agent

# Install dependencies
pip install -e .

# Set environment variables
export GOOGLE_API_KEY=your-api-key

# Start locally (for testing)
kagent-adk run agent --host 0.0.0.0 --port 8080
```

### 2. Build and push the container image

```bash
# Build
docker build -t ghcr.io/YOUR_ORG/custom-adk-agent:latest ./agent

# Push
docker push ghcr.io/YOUR_ORG/custom-adk-agent:latest
```

### 3. Update k8s/agent.yaml

Replace `image: ghcr.io/YOUR_ORG/custom-adk-agent:latest` with your actual image path.

### 4. Deploy to Kubernetes

```bash
kubectl apply -f k8s/agent.yaml
```

### 5. Test in the kagent UI

kagent automatically detects the new Agent CRD. `custom-adk-agent` will appear in the UI, ready to chat with.

---

## About the kagent-adk CLI

`kagent-adk` is a wrapper that:

1. Loads the `root_agent` object from your `agent.py`
2. Starts an HTTP server on the specified host:port
3. Implements A2A protocol endpoints (`/`, `/.well-known/agent.json`, `/run`, etc.)

No need to write any HTTP server code yourself.

```dockerfile
# Last line of the Dockerfile
CMD ["kagent-adk", "run", "agent", "--host", "0.0.0.0", "--port", "8080"]
#                          ↑
#              module name of agent.py (without .py)
```

---

## ADK Features You Can Customize (Examples)

| Feature | Code |
|---------|------|
| BuiltInPlanner | `planner=BuiltInPlanner(thinking_config=...)` |
| Before/After callback | `before_agent_callback=my_fn` |
| Multiple sub-agents | `sub_agents=[agent_a, agent_b]` |
| Custom output schema | `output_schema=MyPydanticModel` |
| Safety settings | `generate_content_config=GenerateContentConfig(...)` |

None of these are configurable in Declarative agents. BYO agents support all of them.
