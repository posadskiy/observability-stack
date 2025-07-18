# Observability Stack for Local Development

This repository contains a Docker Compose setup for local development with centralized logging using Loki and Grafana for visualization, distributed tracing with Jaeger, and metrics collection with Prometheus.

## Components

- **Loki**: Centralized log storage and aggregation
- **Grafana**: Visualization and dashboards for logs, traces, and metrics
- **Promtail**: Log collection agent (collects logs from Docker containers)
- **Jaeger**: Distributed tracing system
- **Prometheus**: Metrics collection and storage

## Quick Start

1. **Start the stack:**
   ```bash
   docker-compose -f docker-compose.dev.yaml up -d
   ```

2. **Access the services:**
   - **Grafana**: http://localhost:3000 (admin/admin)
   - **Loki**: http://localhost:3100
   - **Jaeger UI**: http://localhost:16686
   - **Prometheus**: http://localhost:9090

3. **View logs in Grafana:**
   - Navigate to Explore in Grafana
   - Select Loki as the data source
   - Use queries like `{job="docker"}` to view all container logs
   - Use `{job="docker"} |= "error"` to filter error logs

4. **View traces in Grafana:**
   - Navigate to Explore in Grafana
   - Select Jaeger as the data source
   - Use the trace query interface to search for traces
   - View the "Tracing Overview" dashboard

5. **View traces in Jaeger UI:**
   - Go to http://localhost:16686
   - Search for traces by service name, operation, or tags
   - View trace details and dependencies

6. **View metrics in Grafana:**
   - Navigate to Dashboards in Grafana
   - View "Observability Stack Overview" and "Application Metrics" dashboards
   - Or go to Explore and select Prometheus data source to query metrics directly

7. **View metrics in Prometheus:**
   - Go to http://localhost:9090
   - Use the query interface to explore metrics
   - View targets to see what's being scraped

## Configuration

### Loki Configuration
- Located in `config/loki/local-config.yaml`
- Configured for local development with file-based storage
- Log retention: 31 days (744 hours)

### Promtail Configuration
- Located in `config/promtail/config.yml`
- Collects logs from Docker containers and system logs
- Automatically parses JSON logs from Docker

### Grafana Configuration
- Auto-provisioned Loki and Jaeger data sources
- Sample dashboards for log and trace visualization
- Default credentials: admin/admin

### Jaeger Configuration
- All-in-one deployment with collector, query, and storage
- Supports multiple protocols: Thrift, gRPC, HTTP, OTLP
- In-memory storage for development (use external storage for production)

### Prometheus Configuration
- Located in `config/prometheus/prometheus.yml`
- Scrapes metrics from all observability stack components
- Automatically configured to scrape application metrics
- Data retention: 200 hours (8+ days)
- Scrape interval: 15 seconds (configurable per job)

## Adding Your Microservices

To add your microservices to this stack:

1. **Add your service to docker-compose.dev.yaml:**
   ```yaml
   your-service:
     image: your-service-image
     container_name: your-service
     ports:
       - "8081:8080"
     logging:
       driver: "json-file"
       options:
         max-size: "10m"
         max-file: "3"
     networks:
       - observability-stack
     restart: unless-stopped
   ```

2. **Ensure your service logs to stdout/stderr** (Docker will capture these automatically)

3. **Add metrics to your service** using Prometheus client libraries:
   ```python
   from prometheus_client import Counter, Histogram, generate_latest
   
   # Define metrics
   REQUEST_COUNT = Counter('http_requests_total', 'Total HTTP requests', ['method', 'endpoint'])
   REQUEST_LATENCY = Histogram('http_request_duration_seconds', 'HTTP request latency')
   
   # Expose metrics endpoint
   @app.route('/metrics')
   def metrics():
       return generate_latest()
   ```

4. **Add tracing to your service** using OpenTelemetry:
   ```python
   from opentelemetry import trace
   from opentelemetry.exporter.jaeger.thrift import JaegerExporter
   from opentelemetry.sdk.trace import TracerProvider
   from opentelemetry.sdk.trace.export import BatchSpanProcessor
   
   # Initialize tracing
   trace.set_tracer_provider(TracerProvider())
   jaeger_exporter = JaegerExporter(
       agent_host_name="jaeger",
       agent_port=6831,
   )
   trace.get_tracer_provider().add_span_processor(
       BatchSpanProcessor(jaeger_exporter)
   )
   ```

5. **View logs in Grafana** using queries like:
   - `{container_name="your-service"}` - View logs from your specific service
   - `{container_name="your-service"} |= "error"` - View error logs from your service

6. **View metrics in Grafana** using the Application Metrics dashboard or custom queries:
   - `rate(http_requests_total[5m])` - Request rate
   - `rate(http_request_duration_seconds_sum[5m]) / rate(http_request_duration_seconds_count[5m])` - Average response time

7. **View traces in Jaeger** by searching for your service name

## Testing the Tracing Setup

1. **Start the stack:**
   ```bash
   docker-compose -f docker-compose.dev.yaml up -d
   ```

2. **Add your own service** with OpenTelemetry instrumentation

3. **Generate some traffic** to your service

4. **View traces:**
   - Open http://localhost:16686 (Jaeger UI)
   - Search for your service name
   - View trace details and dependencies

5. **View traces in Grafana:**
   - Open http://localhost:3000
   - Go to Explore
   - Select Jaeger data source
   - Search for traces

## Useful Log Queries

### Basic Queries
- `{job="docker"}` - All container logs
- `{container_name="service-name"}` - Logs from specific container
- `{job="docker"} |= "error"` - Error logs
- `{job="docker"} |= "warn"` - Warning logs

### Advanced Queries
- `{job="docker"} |= "error" | json` - Parse JSON error logs
- `{job="docker"} |~ "(?i)exception|error|fail"` - Case-insensitive error matching
- `{job="docker"} | json | level="error"` - JSON logs with error level

## Useful Trace Queries

### In Jaeger UI
- Service: `your-service-name` - View all traces from your service
- Operation: `operation-name` - View specific operations
- Tags: `error=true` - View traces with errors

### In Grafana
- Use the Jaeger data source to query traces
- View the "Tracing Overview" dashboard for metrics

## Useful Metrics Queries

### Basic Metrics
- `up` - Service health status (1 = up, 0 = down)
- `up{job="your-service"}` - Health status for specific service
- `scrape_duration_seconds` - How long Prometheus takes to scrape each target

### Application Metrics
- `rate(http_requests_total[5m])` - Request rate over 5 minutes
- `rate(http_requests_total{status=~"4..|5.."}[5m])` - Error rate (4xx/5xx responses)
- `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))` - 95th percentile response time
- `process_cpu_seconds_total` - CPU usage
- `process_resident_memory_bytes / 1024 / 1024` - Memory usage in MB

### Observability Stack Metrics
- `prometheus_tsdb_head_samples_appended_total` - Prometheus samples ingested
- `loki_build_info` - Loki version information
- `jaeger_build_info` - Jaeger version information
- `grafana_build_info` - Grafana version information

### Advanced Queries
- `sum(rate(http_requests_total[5m])) by (method, endpoint)` - Request rate by method and endpoint
- `increase(http_requests_total[1h])` - Total requests in the last hour
- `rate(http_request_duration_seconds_sum[5m]) / rate(http_request_duration_seconds_count[5m])` - Average response time

## Stopping the Stack

```bash
docker-compose -f docker-compose.dev.yaml down
```

To remove volumes (this will delete all stored logs and traces):
```bash
docker-compose -f docker-compose.dev.yaml down -v
```

## Troubleshooting

### Grafana can't connect to Loki or Jaeger
- Ensure all services are running: `docker-compose -f docker-compose.dev.yaml ps`
- Check service logs: `docker-compose -f docker-compose.dev.yaml logs <service-name>`
- Verify services are accessible: 
  - `curl http://localhost:3100/ready` (Loki)
  - `curl http://localhost:16686/api/services` (Jaeger)

### No traces appearing
- Check if your service is properly instrumented with OpenTelemetry
- Verify the Jaeger exporter is configured correctly
- Check Jaeger logs: `docker-compose -f docker-compose.dev.yaml logs jaeger`

### No metrics appearing
- Check Prometheus targets: http://localhost:9090/targets
- Verify your service exposes metrics at `/metrics` endpoint
- Check Prometheus logs: `docker-compose -f docker-compose.dev.yaml logs prometheus`
- Ensure your service is in the same Docker network as Prometheus
- Verify the service is configured in `config/prometheus/prometheus.yml`

### No logs appearing
- Check Promtail logs: `docker-compose -f docker-compose.dev.yaml logs promtail`
- Verify containers are generating logs
- Check if logs are being written to stdout/stderr in your containers

### Performance Issues
- For high log volume, consider adjusting Loki's configuration
- Monitor disk usage of the `loki-data` and `jaeger-data` volumes
- Consider increasing log rotation settings in your services

## Customization

### Adding Custom Dashboards
1. Create JSON dashboard files in `config/grafana/dashboards/`
2. Restart Grafana or wait for auto-reload
3. Dashboards will appear in Grafana's dashboard list

### Modifying Log Collection
- Edit `config/promtail/config.yml` to add custom log sources
- Add volume mounts for custom log directories
- Configure custom log parsing pipelines

### Loki Configuration
- Modify `config/loki/local-config.yaml` for different storage backends
- Adjust retention periods and chunk settings
- Configure authentication if needed

### Jaeger Configuration
- Modify environment variables for different storage backends
- Configure sampling rates for production use
- Add authentication and security settings 

### Prometheus Configuration
- Edit `config/prometheus/prometheus.yml` to add new scrape targets
- Configure alerting rules in separate rule files
- Adjust retention periods and scrape intervals
- Add custom relabeling rules for better metric organization 