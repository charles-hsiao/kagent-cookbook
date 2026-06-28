#!/usr/bin/env bash
# Setup a kind cluster with kagent installed.
# Run this once before deploying any demo.
#
# Usage:
#   GOOGLE_API_KEY=<your-key> ./scripts/kind-setup.sh
#   GOOGLE_API_KEY=<your-key> CLUSTER_NAME=my-cluster ./scripts/kind-setup.sh
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-kind}"
KAGENT_NAMESPACE="${KAGENT_NAMESPACE:-kagent}"
KAGENT_VERSION="${KAGENT_VERSION:-}"   # leave blank to install latest

# ── Prerequisites ──────────────────────────────────────────────────────────────
for cmd in kind kubectl helm docker; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: '$cmd' not found. Please install it first." >&2
    exit 1
  fi
done

if [[ -z "${GOOGLE_API_KEY:-}" ]]; then
  echo "ERROR: GOOGLE_API_KEY is not set." >&2
  echo "  Export it before running: export GOOGLE_API_KEY=<your-key>" >&2
  exit 1
fi

# ── Kind cluster ───────────────────────────────────────────────────────────────
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  echo "✓ kind cluster '${CLUSTER_NAME}' already exists — skipping creation"
else
  echo "→ Creating kind cluster '${CLUSTER_NAME}' ..."
  kind create cluster --name "${CLUSTER_NAME}" --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      # Expose kagent UI / API on localhost:8080
      - containerPort: 30080
        hostPort: 8080
        protocol: TCP
EOF
  echo "✓ kind cluster '${CLUSTER_NAME}' created"
fi

# Point kubectl at the new cluster
kubectl config use-context "kind-${CLUSTER_NAME}"

# ── Namespace ──────────────────────────────────────────────────────────────────
kubectl get namespace "${KAGENT_NAMESPACE}" &>/dev/null \
  || kubectl create namespace "${KAGENT_NAMESPACE}"

# ── Google API key secret ──────────────────────────────────────────────────────
if kubectl get secret kagent-google -n "${KAGENT_NAMESPACE}" &>/dev/null; then
  echo "✓ Secret 'kagent-google' already exists — skipping"
else
  echo "→ Creating secret 'kagent-google' ..."
  kubectl create secret generic kagent-google \
    --from-literal=GOOGLE_API_KEY="${GOOGLE_API_KEY}" \
    -n "${KAGENT_NAMESPACE}"
  echo "✓ Secret created"
fi

# ── kagent helm chart ──────────────────────────────────────────────────────────
if ! helm repo list 2>/dev/null | grep -q "^kagent"; then
  echo "→ Adding kagent helm repo ..."
  helm repo add kagent https://kagent-dev.github.io/kagent
fi
helm repo update kagent

HELM_ARGS=(
  kagent kagent/kagent
  --namespace "${KAGENT_NAMESPACE}"
  --create-namespace
  --set googleApiKey="${GOOGLE_API_KEY}"
  # Expose the UI as a NodePort so it's reachable at localhost:8080
  --set service.type=NodePort
  --set service.nodePort=30080
  --wait
  --timeout 5m
)
[[ -n "${KAGENT_VERSION}" ]] && HELM_ARGS+=(--version "${KAGENT_VERSION}")

if helm status kagent -n "${KAGENT_NAMESPACE}" &>/dev/null; then
  echo "→ Upgrading kagent helm release ..."
  helm upgrade "${HELM_ARGS[@]}"
else
  echo "→ Installing kagent helm release ..."
  helm install "${HELM_ARGS[@]}"
fi

echo ""
echo "════════════════════════════════════════════════"
echo "✓ kagent is ready!"
echo "  Cluster : ${CLUSTER_NAME}"
echo "  UI/API  : http://localhost:8080"
echo ""
echo "Next steps:"
echo "  Deploy demo-01 → demo-01-byo-full-control/deploy-kind.sh"
echo "  Deploy demo-02 → demo-02-tool-reuse/deploy-kind.sh"
echo "════════════════════════════════════════════════"
