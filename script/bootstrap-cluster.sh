#!/usr/bin/env bash
# bootstrap-cluster.sh — Bootstrap ArgoCD and apply the root GitOps Application.
#
# Installs ArgoCD via Helm (idempotent), waits for it to be healthy, then
# applies the root ArgoCD Application that hands cluster management to GitOps.
# Waits for the root Application to reach Synced+Healthy before exiting.
#
# Required environment:
#   KUBECONFIG — path to the cluster kubeconfig (set by CI from Terraform output)
#
# Usage (from repository root):
#   KUBECONFIG=/path/to/kubeconfig bash script/bootstrap-cluster.sh

set -euo pipefail

# ── Constants ──────────────────────────────────────────────────────────────────

# renovate: datasource=helm depName=argo-cd registryUrl=https://argoproj.github.io/argo-helm
ARGOCD_CHART_VERSION="9.4.15"

ARGOCD_NAMESPACE="argocd"
ARGOCD_RELEASE="argo-cd"
ARGOCD_ROLLOUT_TIMEOUT="300s"
APP_SYNC_TIMEOUT=120
ARGOCD_SERVER_DEPLOYMENT="${ARGOCD_RELEASE}-argocd-server"
ARGOCD_APP_CONTROLLER_STATEFULSET="${ARGOCD_RELEASE}-argocd-application-controller"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# ── Guards ────────────────────────────────────────────────────────────────────

if [ -z "${KUBECONFIG:-}" ]; then
  echo "ERROR: KUBECONFIG is not set. Export it to the path of your kubeconfig file." >&2
  exit 1
fi

# ── 1. Install ArgoCD via Helm ────────────────────────────────────────────────

echo "==> [1/4] Installing ArgoCD (chart ${ARGOCD_CHART_VERSION}) ..."
helm upgrade --install "${ARGOCD_RELEASE}" \
  oci://ghcr.io/argoproj/argo-helm/argo-cd \
  --version "${ARGOCD_CHART_VERSION}" \
  --namespace "${ARGOCD_NAMESPACE}" \
  --create-namespace \
  --wait \
  --timeout "${ARGOCD_ROLLOUT_TIMEOUT}"
echo "    ArgoCD installed."
echo ""

# ── 2. Wait for ArgoCD rollout ────────────────────────────────────────────────

echo "==> [2/4] Waiting for ${ARGOCD_SERVER_DEPLOYMENT} ..."
kubectl rollout status "deployment/${ARGOCD_SERVER_DEPLOYMENT}" \
  -n "${ARGOCD_NAMESPACE}" \
  --timeout="${ARGOCD_ROLLOUT_TIMEOUT}"

echo "    Waiting for ${ARGOCD_APP_CONTROLLER_STATEFULSET} ..."
kubectl rollout status "statefulset/${ARGOCD_APP_CONTROLLER_STATEFULSET}" \
  -n "${ARGOCD_NAMESPACE}" \
  --timeout="${ARGOCD_ROLLOUT_TIMEOUT}"
echo "    ArgoCD healthy."
echo ""

# ── 3. Apply root Application ─────────────────────────────────────────────────

echo "==> [3/4] Applying root ArgoCD Application ..."
kubectl apply -f "${REPO_ROOT}/bootstrap/root-application.yaml"
echo "    Root Application applied."
echo ""

# ── 4. Wait for root Application to sync ─────────────────────────────────────

echo "==> [4/4] Waiting for root Application to reach Synced+Healthy (up to ${APP_SYNC_TIMEOUT}s) ..."
deadline=$(( $(date +%s) + APP_SYNC_TIMEOUT ))

while true; do
  sync_status=$(kubectl get application root \
    -n "${ARGOCD_NAMESPACE}" \
    -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "")
  health_status=$(kubectl get application root \
    -n "${ARGOCD_NAMESPACE}" \
    -o jsonpath='{.status.health.status}' 2>/dev/null || echo "")

  if [ "${sync_status}" = "Synced" ] && [ "${health_status}" = "Healthy" ]; then
    echo "    Root Application is Synced and Healthy."
    break
  fi

  if [ "$(date +%s)" -ge "${deadline}" ]; then
    echo "ERROR: Root Application did not reach Synced+Healthy within ${APP_SYNC_TIMEOUT}s." >&2
    echo "       sync=${sync_status} health=${health_status}" >&2
    exit 1
  fi

  sleep 5
done
echo ""

echo "Bootstrap complete."
