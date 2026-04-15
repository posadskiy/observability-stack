# Observability Stack — Costy

Grafana Cloud free tier observability for the costy backend (k3s + Micronaut 4 + Java 25).

## Architecture

```
costy services (costy namespace) + microservices (microservices namespace)
  │  metrics → /prometheus endpoint
  │  traces  → OTLP gRPC :4317
  │  logs    → stdout (JSON via LogstashEncoder)
  ▼
Grafana Alloy (observability namespace)
  │  scrapes /prometheus every 15s   → Grafana Cloud Mimir  (metrics)
  │  streams pod logs via k8s API    → Grafana Cloud Loki   (logs)
  │  receives OTLP traces            → Grafana Cloud Tempo  (traces)
  ▼
Grafana Cloud (eu-west-2)
  └── grafana.net dashboard
```

## Prerequisites

- `kubectl` configured for the k3s cluster
- `helm` 3+
- `envsubst` (gettext) — same as other repos’ `k8s/secrets.yaml` flow
- `GRAFANA_OBSERVABILITY_USER_TOKEN` — Cloud Access Policy token (`glc_`) for **Loki + Mimir** (remote_write / push)
- `GRAFANA_OBSERVABILITY_OTLP_TOKEN` — separate `glc_` token for **OTLP** trace ingest (from Grafana → OpenTelemetry → Configure)

Secrets: `k8s/secrets.yaml` maps `token` and `otlpToken`; `deploy.sh` runs `envsubst` on both variables.

```bash
export GRAFANA_OBSERVABILITY_USER_TOKEN=glc_...
export GRAFANA_OBSERVABILITY_OTLP_TOKEN=glc_...
```

## Deploy Grafana Alloy

```bash
./deploy.sh
```

Alloy starts collecting logs immediately (no service rebuild needed for logs).

**Namespaces in Alloy:** `discovery.kubernetes` is restricted to an explicit list (see `config/alloy/config.alloy` and `helm/alloy/values.yaml`). Today that list includes **`costy`** and **`microservices`**. Pods in any other namespace are not shipped to Loki/Mimir until you add that namespace there and redeploy Alloy.

## Costy backend (already wired)

The **costy** repo (`cost-accounting-backend`) already includes Micrometer, Prometheus scrape annotations, and OTel env vars on deployments.

Rebuild and redeploy when you change dependencies or config:

```bash
cd ../costy/cost-accounting-backend
./mvnw clean package -DskipTests
kubectl rollout restart deployment -n costy
```

## Grafana Cloud endpoints

| Signal | URL | Instance ID |
|---|---|---|
| Metrics (Mimir) | `https://prometheus-prod-65-prod-eu-west-2.grafana.net/api/prom/push` | `3097590` |
| Logs (Loki) | `https://logs-prod-012.grafana.net/loki/api/v1/push` | `1544470` |
| Traces ingest (OTLP HTTP via Alloy) | `https://otlp-gateway-prod-eu-west-2.grafana.net/otlp` (path `/v1/traces` appended by Alloy) | instance ID from stack **OpenTelemetry** tile (Basic auth user) |

## Frontend observability

### Grafana Faro RUM (Real User Monitoring)

The `costy-frontend` React app ships `@grafana/faro-web-sdk` and `@grafana/faro-web-tracing`.

**One-time Grafana Cloud setup:**

1. Grafana Cloud → **Frontend Observability** → **Add new app** → name `costy`.
2. The Faro collector URL is already hardcoded in `build-and-push.sh` — no extra steps needed.
3. For de-obfuscated stack traces, set `GRAFANA_OBSERVABILITY_FARO_TOKEN` before running the build script  
   (Grafana Cloud → Access Policies → `faro-observability-token` → Add token):

```bash
export GRAFANA_OBSERVABILITY_FARO_TOKEN=glc_...
./deployment/scripts/build-and-push.sh <version>
```

Without the token the build still succeeds; source maps are simply not uploaded and stack traces
in error reports show minified code. All other RUM functionality is unaffected.

**What you get:**
- Core Web Vitals (LCP, CLS, INP) per page route in **Grafana Cloud → Frontend Observability**
- JS errors with stack traces grouped by fingerprint
- Console errors captured as Faro log events
- W3C `traceparent` header injected into every `fetch`/XHR → backend Micronaut spans are
  linked to the browser trace root in **Explore → Tempo**

---

### Nginx access logs (costy-frontend)

`nginx.prod.conf` now writes structured JSON to stdout. Alloy's existing `costy` log pipeline
picks up the frontend pod automatically (same `costy` namespace). Nginx logs are processed by a
dedicated `stage.match` block that:

- Parses `status`, `method`, `uri`, `duration` fields
- Exposes `status` as a Loki stream label (filter: `{status=~"5.."}`)
- Drops `/health` probe lines

Query in **Grafana Cloud → Explore → Loki:**

```logql
{namespace="costy", service="cost-accounting-frontend"} | status =~ "5.."
```

```logql
rate({namespace="costy", service="cost-accounting-frontend"}[5m])
```

---

### Synthetic Monitoring (uptime checks)

Grafana Cloud Synthetic Monitoring runs probes from multiple regions every minute with no
in-cluster agent required for HTTP checks.

**Setup (one-time, in Grafana Cloud UI):**

1. Grafana Cloud → **Synthetic Monitoring** → **Add check** → **HTTP**.
2. Create the following checks:

| Check | URL | Expected | Alert threshold |
|-------|-----|----------|----------------|
| Frontend up | `https://<your-domain>/` | Status 200, body contains `<div id="root">` | Uptime < 99% |
| Frontend health | `https://<your-domain>/health` | Status 200, body `healthy` | Any failure |
| Auth service | `https://<your-domain>/api/auth/health` | Status 200 | Any failure |

3. For each check enable **TLS certificate expiry** alert (default: warn at 30 days).
4. Set **alert policy** → notify on 2 consecutive failures (~2 min detection time).

**Where to see results:** Grafana Cloud → Synthetic Monitoring → built-in dashboard shows
uptime %, response time history, and probe map by region.

---

## Verifying data flow

**Logs** (after Alloy deploy):

```
Grafana Cloud → Explore → Loki → {namespace="costy"}
Grafana Cloud → Explore → Loki → {namespace="microservices"}
Grafana Cloud → Explore → Loki → {namespace="skill-repeater"}
```

**Metrics** (after service rebuild + redeploy):

```
Grafana Cloud → Explore → Prometheus → jvm_memory_used_bytes{namespace="costy"}
Grafana Cloud → Explore → Prometheus → jvm_memory_used_bytes{namespace="microservices"}
Grafana Cloud → Explore → Prometheus → jvm_memory_used_bytes{namespace="skill-repeater"}
```

**Traces**:

```
Grafana Cloud → Explore → Tempo → search by service name
```

**Alloy:**

```bash
kubectl get pods -n observability
kubectl logs -n observability -l app.kubernetes.io/name=alloy -f
```

## Free tier limits

| Resource | Limit | Estimated usage |
|---|---|---|
| Metrics series | 10,000 | ~8,000 (4 services + JVM) |
| Logs | 50 GB/month | ~25 GB/month at INFO level |
| Traces | 50 GB/month | ~10 GB/month at 20% sampling |
| Retention | 14 days | — |

## Low-resource tuning

Defaults assume a **small k3s node and low request volume**:

| Area | Setting |
|------|---------|
| Alloy CPU/RAM | requests `25m` / `64Mi`, limits `200m` / `256Mi` |
| Config reloader | requests `5m` / limits `50m`, memory `16Mi` / `32Mi` |
| Prometheus scrape | every **60s** (was 15s) — less CPU and remote-write churn |
| Trace batches | smaller buffers (`send_batch_size` 256, max 512) |
| Alloy self-logging | level **info** (`warn` makes `kubectl logs` look empty when healthy) |
| Usage reporting | `enableReporting: false` |

If Alloy OOMs or scrapes time out, raise `alloy.resources.limits.memory` slightly (e.g. to `320Mi`) or increase `scrape_timeout`.

**Grafana Cloud Loki `400` / “timestamp too old”:** Hosted Loki only accepts log lines within a recent window (~7 days past the line timestamp). Kubernetes log streaming can replay lines with old `@timestamp` in JSON; the `loki.process` pipeline drops entries older than **120h** before push. Increase or decrease `older_than` in `helm/alloy/values.yaml` if your stack’s limit differs.

**`env()` deprecation warnings:** Config uses `sys.env(...)` (e.g. `GRAFANA_OBSERVABILITY_USER_TOKEN`, `GRAFANA_OBSERVABILITY_OTLP_TOKEN`) instead of deprecated `env(...)`.

## Repo layout

```
observability-stack/
├── README.md
├── .env.example
├── deploy.sh
├── config/alloy/config.alloy   # mirror of Helm config (edit helm/alloy/values.yaml to change)
├── helm/alloy/values.yaml
└── k8s/
    ├── namespace.yaml
    └── secrets.yaml           # token + otlpToken via envsubst
```
