#!/usr/bin/env bash
# Build the demo-01 agent image, load it into kind, and deploy to the cluster.
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
IMAGE_NAME="kagent-demo01-agent:dev"

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

# ── Build image ────────────────────────────────────────────────────────────────
echo "→ Building image '${IMAGE_NAME}' from demo-01-byo-full-control/agent/ ..."
docker build -t "${IMAGE_NAME}" "${SCRIPT_DIR}/agent"
echo "✓ Image built"

# ── Load image into kind ───────────────────────────────────────────────────────
echo "→ Loading image into kind cluster '${CLUSTER_NAME}' ..."
kind load docker-image "${IMAGE_NAME}" --name "${CLUSTER_NAME}"
echo "✓ Image loaded"

# ── Apply manifests ────────────────────────────────────────────────────────────
# Substitute the placeholder image name and set imagePullPolicy: Never so kind
# uses the locally loaded image instead of trying to pull from a registry.
echo "→ Applying k8s manifests ..."
sed \
  -e "s|image: ghcr.io/YOUR_ORG/custom-adk-agent:latest|image: ${IMAGE_NAME}|g" \
  "${SCRIPT_DIR}/k8s/agent.yaml" \
| kubectl apply -f - -n "${NAMESPACE}"

# Patch imagePullPolicy to Never on the BYO agent deployment that kagent creates.
# kagent names the deployment after the Agent CR: custom-adk-agent
echo "→ Waiting for kagent to create the Deployment ..."
for i in $(seq 1 30); do
  if kubectl get deployment custom-adk-agent -n "${NAMESPACE}" &>/dev/null; then
    break
  fi
  sleep 2
done

if kubectl get deployment custom-adk-agent -n "${NAMESPACE}" &>/dev/null; then
  kubectl patch deployment custom-adk-agent -n "${NAMESPACE}" \
    --type=json \
    -p='[{"op":"replace","path":"/spec/template/spec/containers/0/imagePullPolicy","value":"Never"}]'
  echo "✓ imagePullPolicy set to Never"
else
  echo "⚠ Deployment not found after 60s — kagent may still be processing the CRD."
  echo "  Run manually after it appears:"
  echo "  kubectl patch deployment custom-adk-agent -n ${NAMESPACE} \\"
  echo "    --type=json -p='[{\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/imagePullPolicy\",\"value\":\"Never\"}]'"
fi

echo ""
echo "════════════════════════════════════════════════"
echo "✓ Demo 01 deployed!"
echo ""
echo "Check status:"
echo "  kubectl get agent custom-adk-agent -n ${NAMESPACE}"
echo "  kubectl get pod -n ${NAMESPACE} -l app=custom-adk-agent"
echo ""
echo "View logs:"
echo "  kubectl logs -n ${NAMESPACE} -l app=custom-adk-agent -f"
echo ""
echo "Test in kagent UI: http://localhost:8080"
echo "════════════════════════════════════════════════"
