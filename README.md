# Observability Stack

Grafana Alloy on the k3s cluster, shipping metrics, logs and traces to Grafana Cloud (free tier, eu-west-2).

```
pods (annotated prometheus.io/scrape) + kubelet cAdvisor + OTLP :4317
  └─► Grafana Alloy (observability ns) ─► Mimir (metrics) · Loki (logs) · Tempo (traces)
```

## Deploy

Needs `kubectl`, `helm` 3+, `envsubst`, and two `glc_` tokens:

```bash
export GRAFANA_OBSERVABILITY_USER_TOKEN=glc_...   # Loki + Mimir
export GRAFANA_OBSERVABILITY_OTLP_TOKEN=glc_...   # OTLP / traces
./deploy.sh --dry-run
./deploy.sh
```

- **Config:** `config/alloy/config.alloy` is the only pipeline file. `deploy.sh` passes it to Helm via `--set-file`.
  `helm/alloy/values.yaml` holds only resources, env and RBAC, so never run `helm upgrade` with it alone.
- **Chart version:** pinned in `deploy.sh` (`ALLOY_CHART_VERSION`, now `1.7.0` = Alloy v1.15.0).
  To upgrade: `ALLOY_CHART_VERSION=<new> ./deploy.sh --dry-run`, then bump the default.
- **Syntax check (Docker):** `./scripts/validate-config.sh`

## Adding a service

- **Namespace:** add it to `discovery.kubernetes "pods"` in `config/alloy/config.alloy` (and to the cAdvisor namespace regex), then redeploy.
  Watched now: costy, microservices, grammarbar, cocktailcheck, website.
- **App metrics:** annotate the pod with `prometheus.io/scrape: "true"`, `prometheus.io/path`, `prometheus.io/port`.
  Pods without it still ship logs and cAdvisor CPU/memory/network.
- **Traces:** set the service's OTLP endpoint to `http://grafana-alloy.observability.svc.cluster.local:4317`.

## Dashboards

Folder **Observability** in Grafana, two dashboards linked to each other:

- **Backend — Services Overview** (`dashboards/backend-services.json`, uid `k3s-services`): request rate, errors, latency, JVM, logs, node and pod CPU/memory/network (variables: namespace, service).
- **Frontend — Web Overview** (`dashboards/frontend-web.json`, uid `frontend-web`): real user monitoring from Grafana Faro, built from the Faro data in Loki and browser traces in Tempo: sessions, Core Web Vitals (LCP, INP, CLS, TTFB p75), JS errors by page and release, browser-side API latency and errors, slowest browser traces, audience (variable: app).

Import: Grafana → Dashboards → New → Import. After editing one in Grafana, export it and commit the JSON.
Backend and browser spans share a trace id, so a slow API call on the frontend dashboard opens the backend spans in Tempo.

## Checks

```bash
kubectl get pods -n observability
kubectl logs -n observability -l app.kubernetes.io/name=alloy -f
```

Grafana → Explore: Loki `{namespace="grammarbar"}`, Prometheus `jvm_memory_used_bytes{cluster="k3s-prod"}`.

## Notes

- **Free-tier limits:** 10k metric series, 50 GB logs/month, 14-day retention. Check Grafana → Cardinality management after adding metrics.
- **Low-resource tuning:** Alloy requests 25m CPU / 64Mi, limit 200m / 256Mi (raise the memory limit or `scrape_timeout` if it OOMs or times out). Scrape interval is 60s.
- **Loki "timestamp too old" (400):** the pipeline drops lines older than 120h (`older_than` in `config.alloy`).
- **Endpoints:** Mimir `prometheus-prod-65-prod-eu-west-2.grafana.net` (instance 3097590), Loki `logs-prod-012.grafana.net` (1544470), OTLP `otlp-gateway-prod-eu-west-2.grafana.net`.

## Layout

```
deploy.sh                   config/alloy/config.alloy   helm/alloy/values.yaml
dashboards/{backend-services,frontend-web}.json   scripts/validate-config.sh   k8s/{namespace,secrets}.yaml
```
