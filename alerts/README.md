# Alerts

Grafana-managed rules in the `Observability` folder of posadskiy.grafana.net. They run in Grafana Cloud, not on the cluster, so `deploy.sh` is not involved.

Notifications: the default notification policy routes everything to the `Grafana Alert Telegram Bot` contact point (bot token and chat id are set in the Grafana UI, never in this repo).

| Rule | Group | Query | For | Severity |
|---|---|---|---|---|
| Backend down | backend | `up{job="prometheus.scrape.services"} < 1` (no data counts as firing) | 3m | critical |
| High 5xx rate | backend | 5xx share of `http_server_requests_seconds_count` > 10% and >= 5 errors in 5m | 5m | critical |
| Slow responses | backend | `rate(http_server_requests_seconds_sum) / rate(..._count)` > 2s over 10m | 10m | warning |
| Frontend exceptions spike | frontend | `count_over_time({kind="exception"}[10m])` per `service_name` > 20 | 0s | warning |

Each rule groups per `namespace`/`service`, so one message names the project and service. Notifications group by folder and alertname, wait 30s, and repeat every 4h while firing.

To change a rule, edit it in Grafana (Alerting -> Alert rules) and update this table.

Not covered yet (the metrics are not collected): p95 latency, container memory vs limit, pod restarts (needs kube-state-metrics), TLS expiry (needs Synthetic Monitoring).
