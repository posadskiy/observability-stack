#!/usr/bin/env bash
# Deploy Grafana Alloy into the observability namespace (Grafana Cloud backend).
#
# Prerequisites: kubectl, helm 3,
#   GRAFANA_OBSERVABILITY_USER_TOKEN (Loki/Mimir),
#   GRAFANA_OBSERVABILITY_OTLP_TOKEN (OTLP / traces to Grafana Cloud)
#
# Usage:
#   ./deploy.sh
#   ./deploy.sh --dry-run
set -euo pipefail

NAMESPACE="observability"
HELM_RELEASE="grafana-alloy"
SECRET_NAME="grafana-cloud-credentials"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "[dry-run] No changes will be applied."
fi

echo "==> Checking prerequisites..."

if ! command -v kubectl &>/dev/null; then
  echo "ERROR: kubectl not found in PATH" && exit 1
fi

if ! command -v helm &>/dev/null; then
  echo "ERROR: helm not found in PATH" && exit 1
fi

if ! command -v envsubst &>/dev/null; then
  echo "ERROR: envsubst not found (gettext). Install gettext, then retry."
  echo "       macOS: brew install gettext && brew link --force gettext"
  exit 1
fi

if [[ -z "${GRAFANA_OBSERVABILITY_USER_TOKEN:-}" ]]; then
  echo "ERROR: GRAFANA_OBSERVABILITY_USER_TOKEN is not set."
  echo "       export GRAFANA_OBSERVABILITY_USER_TOKEN=glc_..."
  exit 1
fi
if [[ -z "${GRAFANA_OBSERVABILITY_OTLP_TOKEN:-}" ]]; then
  echo "ERROR: GRAFANA_OBSERVABILITY_OTLP_TOKEN is not set."
  echo "       export GRAFANA_OBSERVABILITY_OTLP_TOKEN=glc_...   # from OpenTelemetry → Configure (trace ingest)"
  exit 1
fi

echo "    kubectl: $(kubectl version --client --short 2>/dev/null | head -1)"
echo "    helm:    $(helm version --short)"
echo "    cluster: $(kubectl config current-context)"

echo ""
echo "==> Creating namespace: $NAMESPACE"
if [[ "$DRY_RUN" == "true" ]]; then
  echo "    [dry-run] kubectl apply -f k8s/namespace.yaml"
else
  kubectl apply -f "$SCRIPT_DIR/k8s/namespace.yaml"
fi

echo ""
echo "==> Applying Grafana Cloud credentials secret (envsubst k8s/secrets.yaml)..."
if [[ "$DRY_RUN" == "true" ]]; then
  echo "    [dry-run] envsubst < k8s/secrets.yaml | kubectl apply --dry-run=client -f -"
  envsubst '${GRAFANA_OBSERVABILITY_USER_TOKEN} ${GRAFANA_OBSERVABILITY_OTLP_TOKEN}' < "$SCRIPT_DIR/k8s/secrets.yaml" | kubectl apply --dry-run=client -f -
else
  envsubst '${GRAFANA_OBSERVABILITY_USER_TOKEN} ${GRAFANA_OBSERVABILITY_OTLP_TOKEN}' < "$SCRIPT_DIR/k8s/secrets.yaml" | kubectl apply -f -
  echo "    Secret $SECRET_NAME applied."
fi

echo ""
echo "==> Adding Grafana Helm repository..."
if [[ "$DRY_RUN" == "true" ]]; then
  echo "    [dry-run] helm repo add grafana && helm repo update"
else
  helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
  helm repo update grafana
fi

echo ""
echo "==> Installing / upgrading Grafana Alloy..."
HELM_CMD=(
  helm upgrade --install "$HELM_RELEASE" grafana/alloy
  --namespace "$NAMESPACE"
  --values "$SCRIPT_DIR/helm/alloy/values.yaml"
  --wait
  --timeout 120s
)

if [[ "$DRY_RUN" == "true" ]]; then
  echo "    [dry-run] ${HELM_CMD[*]} --dry-run"
  "${HELM_CMD[@]}" --dry-run
else
  "${HELM_CMD[@]}"
fi

echo ""
echo "==> Rolling out $HELM_RELEASE deployment..."
if [[ "$DRY_RUN" == "true" ]]; then
  echo "    [dry-run] kubectl rollout restart deployment/$HELM_RELEASE -n $NAMESPACE"
else
  kubectl rollout restart deployment/"$HELM_RELEASE" -n "$NAMESPACE"
  kubectl rollout status deployment/"$HELM_RELEASE" -n "$NAMESPACE" --timeout=120s
  echo "    Rollout complete."
fi

echo ""
echo "✓ Grafana Alloy deployed to namespace: $NAMESPACE"
echo ""
echo "Next:"
echo "  kubectl get pods -n $NAMESPACE"
echo "  kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=alloy -f"
echo "  Grafana → Explore → Loki → {namespace=\"costy\"}"
