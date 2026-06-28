#!/usr/bin/env bash
# Build the demo-02 images (MCP tool server + BYO agent), load them into kind,
# and deploy both the MCPServer CRD and the BYO Agent CRD.
#
# Prerequisites:
#   - kind cluster with kagent installed (run ../scripts/kind-setup.sh first)
#   - kubectl pointed at the kind cluster
#
# Usage:
#   ./deploy-kind.sh
#   CLUSTER_NAME=my-cluster ./deploy-kind.sh
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-kind}"
NAMESPACE="${NAMESPACE:-kagent}"
MCP_IMAGE="kagent-demo02-mcp:dev"
AGENT_IMAGE="kagent-demo02-agent:dev"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Prerequisites ──────────────────────────────────────────────────────────────
for cmd in docker kind kubectl; do
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

# ── Google API key secret ──────────────────────────────────────────────────────
if kubectl get secret kagent-google -n "${NAMESPACE}" &>/dev/null; then
  echo "✓ Secret 'kagent-google' already exists"
elif [[ -n "${GOOGLE_API_KEY:-}" ]]; then
  echo "→ Creating secret 'kagent-google' from GOOGLE_API_KEY ..."
  kubectl create secret generic kagent-google \
    --from-literal=GOOGLE_API_KEY="${GOOGLE_API_KEY}" \
    -n "${NAMESPACE}"
  echo "✓ Secret created"
else
  echo "ERROR: Secret 'kagent-google' not found and GOOGLE_API_KEY is not set." >&2
  echo "  Either run ../scripts/kind-setup.sh first, or:" >&2
  echo "  export GOOGLE_API_KEY=<your-key> && ./deploy-kind.sh" >&2
  exit 1
fi

# ── Build images ───────────────────────────────────────────────────────────────
echo "→ Building MCP tool server image '${MCP_IMAGE}' ..."
docker build -t "${MCP_IMAGE}" "${SCRIPT_DIR}/tools"
echo "✓ MCP image built"

echo "→ Building BYO agent image '${AGENT_IMAGE}' ..."
docker build -t "${AGENT_IMAGE}" "${SCRIPT_DIR}/agent"
echo "✓ Agent image built"

# ── Load images into kind ──────────────────────────────────────────────────────
echo "→ Loading images into kind cluster '${CLUSTER_NAME}' ..."
kind load docker-image "${MCP_IMAGE}"   --name "${CLUSTER_NAME}"
kind load docker-image "${AGENT_IMAGE}" --name "${CLUSTER_NAME}"
echo "✓ Images loaded"

# ── Deploy MCPServer CRD ───────────────────────────────────────────────────────
echo "→ Applying MCPServer manifest ..."
sed \
  -e "s|image: ghcr.io/YOUR_ORG/shared-utils-mcp:latest|image: ${MCP_IMAGE}|g" \
  "${SCRIPT_DIR}/k8s/mcp-server.yaml" \
| kubectl apply -f - -n "${NAMESPACE}"
echo "✓ MCPServer CRD applied"

# kagent creates a Deployment named after the MCPServer CR: shared-utils
echo "→ Waiting for kagent to create the MCP Deployment ..."
for i in $(seq 1 30); do
  if kubectl get deployment shared-utils -n "${NAMESPACE}" &>/dev/null; then
    break
  fi
  sleep 2
done

if kubectl get deployment shared-utils -n "${NAMESPACE}" &>/dev/null; then
  kubectl patch deployment shared-utils -n "${NAMESPACE}" \
    --type=json \
    -p='[{"op":"replace","path":"/spec/template/spec/containers/0/imagePullPolicy","value":"Never"}]'
  echo "✓ MCP imagePullPolicy set to Never"
else
  echo "⚠ MCP Deployment not found after 60s — patch manually once it appears:"
  echo "  kubectl patch deployment shared-utils -n ${NAMESPACE} \\"
  echo "    --type=json -p='[{\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/imagePullPolicy\",\"value\":\"Never\"}]'"
fi

# Wait for MCP Service to be ready before deploying the agent that connects to it
echo "→ Waiting for shared-utils Service ..."
kubectl wait --for=condition=available deployment/shared-utils \
  -n "${NAMESPACE}" --timeout=120s 2>/dev/null \
  || echo "⚠ MCP deployment not ready yet — continuing anyway"

# ── Deploy BYO Agent CRD ───────────────────────────────────────────────────────
echo "→ Applying BYO agent manifest ..."
sed \
  -e "s|image: ghcr.io/YOUR_ORG/byo-mcp-agent:latest|image: ${AGENT_IMAGE}|g" \
  "${SCRIPT_DIR}/k8s/byo-agent.yaml" \
| kubectl apply -f - -n "${NAMESPACE}"
echo "✓ BYO Agent CRD applied"

echo "→ Waiting for kagent to create the agent Deployment ..."
for i in $(seq 1 30); do
  if kubectl get deployment byo-agent-with-shared-tools -n "${NAMESPACE}" &>/dev/null; then
    break
  fi
  sleep 2
done

if kubectl get deployment byo-agent-with-shared-tools -n "${NAMESPACE}" &>/dev/null; then
  kubectl patch deployment byo-agent-with-shared-tools -n "${NAMESPACE}" \
    --type=json \
    -p='[{"op":"replace","path":"/spec/template/spec/containers/0/imagePullPolicy","value":"Never"}]'
  echo "✓ Agent imagePullPolicy set to Never"
else
  echo "⚠ Agent Deployment not found after 60s — patch manually once it appears:"
  echo "  kubectl patch deployment byo-agent-with-shared-tools -n ${NAMESPACE} \\"
  echo "    --type=json -p='[{\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/imagePullPolicy\",\"value\":\"Never\"}]'"
fi

echo ""
echo "════════════════════════════════════════════════"
echo "✓ Demo 02 deployed!"
echo ""
echo "Check status:"
echo "  kubectl get mcpserver shared-utils -n ${NAMESPACE}"
echo "  kubectl get agent byo-agent-with-shared-tools -n ${NAMESPACE}"
echo "  kubectl get pods -n ${NAMESPACE}"
echo ""
echo "Verify MCP connectivity from the agent pod:"
echo "  kubectl exec -n ${NAMESPACE} -it deploy/byo-agent-with-shared-tools -- \\"
echo "    curl http://shared-utils.${NAMESPACE}.svc.cluster.local:3000/sse"
echo ""
echo "Test in kagent UI: http://localhost:8080"
echo "════════════════════════════════════════════════"
