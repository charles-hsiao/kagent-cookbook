# Demo 03: Local LLM via Ollama on kagent

## Problem Addressed

> "I want to run an agent without sending data to a cloud provider — how do I use a local LLM with kagent?"

**Answer: Use a `ModelConfig` with `provider: Ollama`. Deploy Ollama inside the cluster, pull your model, and point any kagent agent at it.**

---

## Core Concept

The kagent `ModelConfig` CRD decouples the agent definition from the LLM provider choice.

```
Agent CRD
  └── spec.declarative.modelConfig: ollama-llama32
                                         │
                                         ▼
                                   ModelConfig CRD
                                     provider: Ollama
                                     model: llama3.2
                                     host: http://ollama.ollama.svc.cluster.local
                                         │
                                         ▼
                               Ollama Service (cluster-internal)
                                 Deployment: ollama/ollama
                                 Model: llama3.2 (~2 GB)
```

Switching from a cloud provider to Ollama requires only changing the `ModelConfig` — the agent code and tools stay the same.

---

## Contrast with Demo 01 / 02 (BYO Agents)

| | Demo 01/02 (BYO) | Demo 03 (Declarative + Ollama) |
|---|---|---|
| Agent runtime | Your container | Managed by kagent |
| Docker build required | ✓ | — |
| Cloud API key required | ✓ (Gemini) | — |
| Model config | Hardcoded in `agent.py` | `ModelConfig` CRD (swappable YAML) |
| Data privacy | Sent to cloud | Stays in-cluster |

---

## Directory Structure

```
demo-03-local-llm/
├── deploy-kind.sh
└── k8s/
    ├── ollama.yaml        # Namespace + Deployment + Service for Ollama
    ├── modelconfig.yaml   # ModelConfig: provider=Ollama, model=llama3.2
    └── agent.yaml         # Declarative Agent referencing the ModelConfig
```

---

## Deployment Steps

### Prerequisites

- kind cluster with kagent installed: `../scripts/kind-setup.sh`
- Docker Desktop configured with **≥ 8 GB memory** (llama3.2 3B needs ~4 GB at runtime)

### Deploy everything

```bash
./deploy-kind.sh
```

The script:
1. Applies `k8s/ollama.yaml` → creates Ollama Deployment + Service in the `ollama` namespace
2. Waits for the Ollama pod to be ready
3. Runs `ollama pull llama3.2` inside the pod (~2 GB download — takes several minutes)
4. Applies `k8s/modelconfig.yaml` and `k8s/agent.yaml`

### Verify

```bash
# Ollama pod is running
kubectl get pod -n ollama

# Model is loaded
kubectl exec -n ollama deploy/ollama -- ollama list

# kagent resources are accepted
kubectl get modelconfig ollama-llama32 -n kagent
kubectl get agent local-llm-agent -n kagent
```

### Test in the UI

Open **http://localhost:8080**, find `local-llm-agent`, and try:

- `List all namespaces in the cluster`
- `What API resources are available?`
- `Explain what a ReplicaSet is`

---

## Customisation

### Use a lighter model

For machines with less memory (e.g., Docker Desktop at 4 GB):

```bash
OLLAMA_MODEL=llama3.2:1b ./deploy-kind.sh
```

Then update `k8s/modelconfig.yaml`:
```yaml
spec:
  model: llama3.2:1b
```

### Switch to a different model

Update the `model` field in `k8s/modelconfig.yaml` and re-apply — no agent rebuild needed:

```yaml
spec:
  model: mistral-nemo   # or gemma3, phi4, etc.
```

Then pull the new model:
```bash
kubectl exec -n ollama deploy/ollama -- ollama pull mistral-nemo
kubectl apply -f k8s/modelconfig.yaml
```

### Point to a different agent

Any kagent Declarative agent can use this ModelConfig by setting:
```yaml
spec:
  declarative:
    modelConfig: ollama-llama32
```

---

## Troubleshooting

**Function calling not working / agent loops**
Llama 3.2 supports tool calling, but results vary. Try:
- `llama3.2:3b` (default) — good tool calling
- `mistral-nemo` — strong tool calling support
- Remove the `tools:` section from `agent.yaml` for a tool-less conversational agent

**Ollama pod OOMKilled**
Increase the memory limit in `k8s/ollama.yaml`, or use a smaller model variant (`llama3.2:1b`).

**Model pull times out**
The `kubectl exec` pull runs synchronously. On slow connections, let it run — it will not time out as long as the terminal session is active.
