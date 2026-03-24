#!/usr/bin/env bash
# verify-platform.sh — Verify that the provisioned cluster is healthy.
#
# Layer 1 checks: cluster connectivity, node readiness, system pod health.
# Layer 2 checks: ArgoCD namespace, pod health, root Application sync status.
# Layer 3 checks: Traefik ingress and cert-manager deployment readiness.
#
# Usage:
#   KUBECONFIG=/path/to/kubeconfig bash script/verify-platform.sh
#
# Exit codes:
#   0 — all checks passed
#   1 — one or more checks failed

set -euo pipefail

KUBECTL_TIMEOUT="30s"
NODE_READY_TIMEOUT="300s"
ARGOCD_NAMESPACE="argocd"

check_ready_deployment() {
  local namespace="$1"
  local deployment="$2"
  local ready_replicas

  ready_replicas="$(kubectl get deployment "${deployment}" \
    -n "${namespace}" \
    -o jsonpath='{.status.readyReplicas}' \
    --request-timeout="${KUBECTL_TIMEOUT}" 2>/dev/null || true)"
  ready_replicas="${ready_replicas:-0}"

  if ! [ "${ready_replicas}" -ge 1 ]; then
    echo "::error::Deployment '${deployment}' in namespace '${namespace}' is not ready." >&2
    echo "         readyReplicas=${ready_replicas}" >&2
    exit 1
  fi

  echo "    ${namespace}/${deployment}: readyReplicas=${ready_replicas}"
}

# ── Layer 1 ───────────────────────────────────────────────────────────────────

echo "==> [1/8] Cluster connectivity"
kubectl cluster-info --request-timeout="${KUBECTL_TIMEOUT}"
echo ""

echo "==> [2/8] Node readiness"
kubectl wait node --all --for=condition=Ready --timeout="${NODE_READY_TIMEOUT}"
echo "    All nodes Ready."
echo ""

echo "==> [3/8] kube-system pod health"
NOT_READY=$(kubectl get pods -n kube-system \
  --field-selector='status.phase!=Running,status.phase!=Succeeded' \
  --no-headers 2>/dev/null | grep -v '^$' || true)
if [ -n "${NOT_READY}" ]; then
  echo "::error::One or more kube-system pods are not healthy:"
  echo "${NOT_READY}"
  exit 1
fi
echo "    All kube-system pods healthy."
echo ""

# ── Layer 2 ───────────────────────────────────────────────────────────────────

echo "==> [4/8] ArgoCD namespace"
if ! kubectl get namespace "${ARGOCD_NAMESPACE}" --request-timeout="${KUBECTL_TIMEOUT}" > /dev/null 2>&1; then
  echo "::error::Namespace '${ARGOCD_NAMESPACE}' does not exist. Was bootstrap-cluster.sh run?" >&2
  exit 1
fi
echo "    Namespace '${ARGOCD_NAMESPACE}' exists."
echo ""

echo "==> [5/8] ArgoCD pod health"
NOT_READY=$(kubectl get pods -n "${ARGOCD_NAMESPACE}" \
  --field-selector='status.phase!=Running,status.phase!=Succeeded' \
  --no-headers 2>/dev/null | grep -v '^$' || true)
if [ -n "${NOT_READY}" ]; then
  echo "::error::One or more ArgoCD pods are not healthy:"
  echo "${NOT_READY}"
  exit 1
fi
echo "    All ArgoCD pods healthy."
echo ""

echo "==> [6/8] Root Application sync status"
SYNC_STATUS=$(kubectl get application root \
  -n "${ARGOCD_NAMESPACE}" \
  -o jsonpath='{.status.sync.status}' \
  --request-timeout="${KUBECTL_TIMEOUT}" 2>/dev/null || echo "Unknown")
HEALTH_STATUS=$(kubectl get application root \
  -n "${ARGOCD_NAMESPACE}" \
  -o jsonpath='{.status.health.status}' \
  --request-timeout="${KUBECTL_TIMEOUT}" 2>/dev/null || echo "Unknown")

if [ "${SYNC_STATUS}" != "Synced" ] || [ "${HEALTH_STATUS}" != "Healthy" ]; then
  echo "::error::Root Application is not Synced+Healthy." >&2
  echo "         sync=${SYNC_STATUS} health=${HEALTH_STATUS}" >&2
  exit 1
fi
echo "    Root Application: sync=${SYNC_STATUS} health=${HEALTH_STATUS}"
echo ""

echo "==> [7/8] Traefik ingress health"
check_ready_deployment "traefik" "traefik"
echo ""

echo "==> [8/8] cert-manager health"
check_ready_deployment "cert-manager" "cert-manager"
check_ready_deployment "cert-manager" "cert-manager-webhook"
check_ready_deployment "cert-manager" "cert-manager-cainjector"
echo ""

echo "Platform verification passed."
