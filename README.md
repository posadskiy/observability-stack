# Observability Stack for Local Development

This repository contains a Docker Compose setup for local development with centralized logging using Loki and Grafana for visualization.

## Components

- **Loki**: Centralized log storage and aggregation
- **Grafana**: Visualization and dashboards for logs
- **Promtail**: Log collection agent (collects logs from Docker containers)
- **Example Service**: Sample nginx service for testing

## Quick Start

1. **Start the stack:**
   ```bash
   docker-compose -f docker-compose.dev.yaml up -d
   ```

2. **Access the services:**
   - **Grafana**: http://localhost:3000 (admin/admin)
   - **Loki**: http://localhost:3100
   - **Example Service**: http://localhost:8080

3. **View logs in Grafana:**
   - Navigate to Explore in Grafana
   - Select Loki as the data source
   - Use queries like `{job="docker"}` to view all container logs
   - Use `{job="docker"} |= "error"` to filter error logs

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
- Auto-provisioned Loki data source
- Sample dashboard for log visualization
- Default credentials: admin/admin

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

3. **View logs in Grafana** using queries like:
   - `{container_name="your-service"}` - View logs from your specific service
   - `{container_name="your-service"} |= "error"` - View error logs from your service

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

## Stopping the Stack

```bash
docker-compose -f docker-compose.dev.yaml down
```

To remove volumes (this will delete all stored logs):
```bash
docker-compose -f docker-compose.dev.yaml down -v
```

## Troubleshooting

### Grafana can't connect to Loki
- Ensure both services are running: `docker-compose -f docker-compose.dev.yaml ps`
- Check Loki logs: `docker-compose -f docker-compose.dev.yaml logs loki`
- Verify Loki is accessible: `curl http://localhost:3100/ready`

### No logs appearing
- Check Promtail logs: `docker-compose -f docker-compose.dev.yaml logs promtail`
- Verify containers are generating logs
- Check if logs are being written to stdout/stderr in your containers

### Performance Issues
- For high log volume, consider adjusting Loki's configuration
- Monitor disk usage of the `loki-data` volume
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