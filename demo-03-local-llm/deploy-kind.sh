#!/usr/bin/env bash
# Deploy demo-03: Ollama + Llama 3.2 inside the kind cluster, and a Declarative
# kagent agent that uses it. No cloud API key is required.
#
# Prerequisites:
#   - kind cluster with kagent installed (run ../scripts/kind-setup.sh first)
#   - kubectl pointed at the kind cluster
#
# Usage:
#   ./deploy-kind.sh
#   CLUSTER_NAME=my-cluster ./deploy-kind.sh
#   OLLAMA_MODEL=llama3.2:1b ./deploy-kind.sh   # smaller model for low-memory machines
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-kind}"
NAMESPACE="${NAMESPACE:-kagent}"
OLLAMA_MODEL="${OLLAMA_MODEL:-llama3.2}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Prerequisites ──────────────────────────────────────────────────────────────
for cmd in kind kubectl; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: '$cmd' not found." >&2
    exit 1
  fi
done

if ! kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  echo "ERROR: kind cluster '${CLUSTER_NAME}' not found." >&2
  echo "  Run ../scripts/kind-setup.sh first." >&2
  exit 1
fi

kubectl config use-context "kind-${CLUSTER_NAME}"

# ── kagent CRD check ───────────────────────────────────────────────────────────
if ! kubectl get crd agents.kagent.dev &>/dev/null; then
  echo "ERROR: kagent CRDs not found in cluster '${CLUSTER_NAME}'." >&2
  echo "  Run ../scripts/kind-setup.sh to install kagent first." >&2
  exit 1
fi
echo "✓ kagent CRDs present"

# ── Deploy Ollama ──────────────────────────────────────────────────────────────
echo "→ Applying Ollama manifests (Namespace + Deployment + Service) ..."
kubectl apply -f "${SCRIPT_DIR}/k8s/ollama.yaml"
echo "✓ Ollama manifests applied"

echo "→ Waiting for Ollama pod to start (may take a minute while pulling ollama/ollama:latest) ..."
kubectl wait --for=condition=available deployment/ollama \
  -n ollama --timeout=300s
echo "✓ Ollama deployment ready"

# ── Pull model into Ollama ─────────────────────────────────────────────────────
echo ""
echo "→ Pulling '${OLLAMA_MODEL}' into Ollama (downloading ~2 GB — please wait) ..."
echo "  Tip: set OLLAMA_MODEL=llama3.2:1b for a lighter ~800 MB model."
kubectl exec -n ollama deploy/ollama -- ollama pull "${OLLAMA_MODEL}"
echo "✓ Model '${OLLAMA_MODEL}' ready"

# ── Apply kagent manifests ─────────────────────────────────────────────────────
echo "→ Applying ModelConfig ..."
kubectl apply -f "${SCRIPT_DIR}/k8s/modelconfig.yaml"
echo "✓ ModelConfig 'ollama-llama32' applied"

echo "→ Applying Declarative Agent ..."
kubectl apply -f "${SCRIPT_DIR}/k8s/agent.yaml"
echo "✓ Agent 'local-llm-agent' applied"

echo ""
echo "════════════════════════════════════════════════"
echo "✓ Demo 03 deployed!"
echo ""
echo "Check status:"
echo "  kubectl get modelconfig ollama-llama32 -n ${NAMESPACE}"
echo "  kubectl get agent local-llm-agent -n ${NAMESPACE}"
echo "  kubectl get pod -n ollama"
echo ""
echo "Verify the model is available:"
echo "  kubectl exec -n ollama deploy/ollama -- ollama list"
echo ""
echo "Test in kagent UI: http://localhost:8080"
echo "  Find 'local-llm-agent' and try: 'List all namespaces in the cluster'"
echo "════════════════════════════════════════════════"
