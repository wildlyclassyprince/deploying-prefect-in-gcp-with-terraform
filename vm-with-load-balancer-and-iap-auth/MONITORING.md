# Monitoring and Logging Guide

## Overview

The Prefect infrastructure now includes comprehensive logging and monitoring via Google Cloud Operations (formerly Stackdriver). All VM logs are automatically collected and centralized in Cloud Logging.

## What's Being Collected

### Logs
- **Prefect Server**: All server logs from systemd journal
- **Prefect Worker**: All worker logs from systemd journal
- **PostgreSQL**: Database logs
- **Startup Script**: VM initialization logs
- **System Logs**: Standard syslog, auth logs, kernel logs

### Metrics
- **Host Metrics**: CPU, memory, disk I/O, network traffic (collected every 60s)
- **Custom Metrics**: Can be added via Ops Agent configuration

## Viewing Logs in Cloud Console

### Quick Access
1. Go to [Cloud Logging](https://console.cloud.google.com/logs)
2. Select your project
3. Use the query builder or Log Explorer

### Pre-built Queries

#### View All Prefect Server Logs
```
resource.type="gce_instance"
log_id("prefect-server")
```

#### View All Prefect Worker Logs
```
resource.type="gce_instance"
log_id("prefect-test-worker")
```

#### View PostgreSQL Logs
```
resource.type="gce_instance"
log_id("postgresql")
```

#### View Startup Script Logs
```
resource.type="gce_instance"
log_id("startup_logs")
```

#### View Only Errors
```
resource.type="gce_instance"
(log_id("prefect-server") OR log_id("prefect-test-worker"))
severity>=ERROR
```

#### View Logs for Specific Instance
```
resource.type="gce_instance"
resource.labels.instance_id="YOUR_INSTANCE_NAME"
```

## Using gcloud CLI

### View Prefect Server Logs (last 10 minutes)
```bash
gcloud logging read "resource.type=gce_instance AND log_id(\"prefect-server\")" \
  --limit=100 \
  --freshness=10m \
  --format=json
```

### View Errors Only
```bash
gcloud logging read "resource.type=gce_instance AND severity>=ERROR" \
  --limit=50 \
  --format="table(timestamp,jsonPayload.message)"
```

### Stream Logs in Real-time
```bash
gcloud logging tail "resource.type=gce_instance AND log_id(\"prefect-server\")"
```

### View Logs for Specific Time Range
```bash
gcloud logging read "resource.type=gce_instance" \
  --format=json \
  --freshness=1h
```

## Security Monitoring

### View Cloud Armor Blocked Requests
```bash
gcloud logging read "resource.type=http_load_balancer AND jsonPayload.enforcedSecurityPolicy.name:prefect-protection" \
  --limit=50 \
  --format=json
```

### View Blocked Null Byte Attacks
```bash
gcloud logging read "resource.type=http_load_balancer AND jsonPayload.enforcedSecurityPolicy.outcome=\"DENY\" AND jsonPayload.statusDetails=\"denied_by_security_policy\"" \
  --limit=50 \
  --format="table(timestamp,httpRequest.requestUrl,httpRequest.remoteIp)"
```

### View Rate Limited IPs
```bash
gcloud logging read "resource.type=http_load_balancer AND httpRequest.status=429" \
  --limit=50 \
  --format="table(timestamp,httpRequest.remoteIp,httpRequest.requestUrl)"
```

## Monitoring Metrics

### View in Cloud Console
1. Go to [Cloud Monitoring](https://console.cloud.google.com/monitoring)
2. Navigate to **Metrics Explorer**
3. Filter by resource type: **VM Instance**
4. Select your instance

### Common Metrics
- `compute.googleapis.com/instance/cpu/utilization` - CPU usage
- `compute.googleapis.com/instance/disk/read_bytes_count` - Disk reads
- `compute.googleapis.com/instance/disk/write_bytes_count` - Disk writes
- `compute.googleapis.com/instance/network/received_bytes_count` - Network in
- `compute.googleapis.com/instance/network/sent_bytes_count` - Network out

### Using gcloud to Query Metrics
```bash
gcloud monitoring time-series list \
  --filter='metric.type="compute.googleapis.com/instance/cpu/utilization"' \
  --format=json
```

## Setting Up Alerts

### Create Alert for High CPU Usage
```bash
gcloud alpha monitoring policies create \
  --notification-channels=CHANNEL_ID \
  --display-name="Prefect VM High CPU" \
  --condition-display-name="CPU > 80%" \
  --condition-threshold-value=0.8 \
  --condition-threshold-duration=300s \
  --condition-expression='
    resource.type = "gce_instance"
    AND metric.type = "compute.googleapis.com/instance/cpu/utilization"
  '
```

### Create Alert for Service Down
```bash
gcloud alpha monitoring policies create \
  --notification-channels=CHANNEL_ID \
  --display-name="Prefect Server Down" \
  --condition-display-name="No logs in 5 min" \
  --condition-absent-duration=300s \
  --condition-expression='
    resource.type = "gce_instance"
    AND log_id("prefect-server")
  '
```

## Log Retention

By default, logs are retained for **30 days** in Cloud Logging. To change retention:

1. Go to Cloud Logging → Log Storage
2. Create a custom retention policy
3. Or create a sink to export logs to Cloud Storage/BigQuery for longer retention

### Export Logs to Cloud Storage
```bash
gcloud logging sinks create prefect-logs-archive \
  storage.googleapis.com/YOUR_BUCKET_NAME \
  --log-filter='resource.type="gce_instance" AND (log_id("prefect-server") OR log_id("prefect-test-worker"))'
```

## Troubleshooting

### Check if Ops Agent is Running
```bash
gcloud compute ssh YOUR_INSTANCE_NAME --command "sudo systemctl status google-cloud-ops-agent"
```

### Verify Agent Configuration
```bash
gcloud compute ssh YOUR_INSTANCE_NAME --command "sudo cat /etc/google-cloud-ops-agent/config.yaml"
```

### Restart Ops Agent
```bash
gcloud compute ssh YOUR_INSTANCE_NAME --command "sudo systemctl restart google-cloud-ops-agent"
```

### View Agent Logs
```bash
gcloud compute ssh YOUR_INSTANCE_NAME --command "sudo journalctl -u google-cloud-ops-agent -f"
```

## Log Analysis Best Practices

1. **Use Log-based Metrics**: Create metrics from log patterns for alerting
2. **Set Up Dashboards**: Create custom dashboards for key metrics
3. **Enable Log Sampling**: For high-volume logs, consider sampling to reduce costs
4. **Use Exclusion Filters**: Exclude noisy logs you don't need
5. **Regular Review**: Periodically review logs for security incidents

## Cost Optimization

Cloud Logging costs are based on log volume. To optimize:

1. **Exclude verbose logs**: Filter out DEBUG level logs in production
2. **Use sampling**: Sample high-volume logs at 10-20%
3. **Adjust retention**: Reduce retention period for less critical logs
4. **Export to Cloud Storage**: For long-term archival at lower cost

### Check Logging Usage
```bash
gcloud logging logs list --format="table(name)"
gcloud logging metrics describe --help
```

## Additional Resources

- [Cloud Logging Documentation](https://cloud.google.com/logging/docs)
- [Cloud Monitoring Documentation](https://cloud.google.com/monitoring/docs)
- [Ops Agent Configuration](https://cloud.google.com/logging/docs/agent/ops-agent/configuration)
- [Log Query Language](https://cloud.google.com/logging/docs/view/logging-query-language)
