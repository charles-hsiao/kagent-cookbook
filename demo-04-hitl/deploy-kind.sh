#!/usr/bin/env bash
# Deploy demo-04: Declarative HITL agent with requireApproval on destructive K8s tools.
# No container build required — kagent manages the agent runtime entirely.
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

# ── Apply manifest ─────────────────────────────────────────────────────────────
echo "→ Applying Declarative HITL Agent ..."
kubectl apply -f "${SCRIPT_DIR}/k8s/hitl-agent.yaml"
echo "✓ Agent 'hitl-agent' applied"

echo ""
echo "════════════════════════════════════════════════"
echo "✓ Demo 04 deployed!"
echo ""
echo "Check status:"
echo "  kubectl get agent hitl-agent -n ${NAMESPACE}"
echo ""
echo "Test in kagent UI: http://localhost:8080"
echo "  Read (no approval)    : 'List all pods in the kagent namespace'"
echo "  Write (needs approval): 'Create a ConfigMap called test-config in the default namespace'"
echo "  Delete (needs approval): 'Delete the ConfigMap test-config in the default namespace'"
echo "  Ambiguous (ask_user)  : 'Set up a namespace for my application'"
echo "════════════════════════════════════════════════"
