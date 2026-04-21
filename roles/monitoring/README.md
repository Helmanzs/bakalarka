# monitoring Role

Installs and configures **Prometheus** and **Grafana** on a dedicated LXD VM.

Prometheus automatically targets all hosts in the `[databases]` inventory group via `node_exporter` (port 9100).  
Grafana is pre-provisioned with a Prometheus datasource and two dashboards.

## Requirements

- Ubuntu 24.04 target VM (created via `common-create` like other DB VMs)
- All database VMs must have `node-exporter` installed (handled automatically by `setup/setup_monitoring.yml`)
- A `monitoring` entry in your inventory with a valid LXD network IP

## Inventory Setup

Add to `inventory/local`:

```ini
[databases]
clickhousedb  ansible_host=10.187.240.10
timescaledb   ansible_host=10.187.240.11
influxdb      ansible_host=10.187.240.12
questdb       ansible_host=10.187.240.13
columnstoredb ansible_host=10.187.240.14
mariadb       ansible_host=10.187.240.15
mongodb       ansible_host=10.187.240.16
iotdb         ansible_host=10.187.240.17

[monitoring]
monitoring ansible_host=10.187.240.50

[servers]
localhost ansible_connection=local
```

## Role Variables

| Variable | Default | Description |
|---|---|---|
| `prometheus_version` | `2.52.0` | Prometheus binary version |
| `prometheus_port` | `9090` | Prometheus web/API port |
| `prometheus_scrape_interval` | `15s` | How often to scrape targets |
| `prometheus_data_dir` | `/var/lib/prometheus` | TSDB storage path |
| `node_exporter_port` | `9100` | Port to scrape on each database VM |
| `grafana_port` | `3000` | Grafana HTTP port |
| `grafana_admin_user` | `admin` | Grafana admin username |
| `grafana_admin_password` | `admin` | Grafana admin password — **change this** |

## Dashboards

Two dashboards are provisioned automatically:

### System Overview (`/d/db-benchmark-system`)
Multi-VM view — compare CPU, memory, disk throughput, network IO and load across all database VMs simultaneously. Use this during parallel test runs.

### DB Benchmark Test Analysis (`/d/db-benchmark-tests`)
Per-VM deep-dive — select a single database from the dropdown to see CPU, memory breakdown, disk IOPS, network, load average and context switches during a test window.

## Deployment

```bash
# Full setup: creates monitoring VM + deploys node_exporter to all DB VMs
ansible-playbook setup/setup_monitoring.yml -e profile=small

# Re-deploy just node_exporter to all database VMs (e.g. after adding a new DB)
ansible-playbook setup/setup_monitoring.yml --tags node_exporter

# Reconfigure Prometheus/Grafana only (VM already exists)
ansible-playbook setup/setup_monitoring.yml --tags monitoring --limit monitoring
```

## Accessing the Stack

After deployment the playbook prints the URLs. By default:

- **Grafana**: `http://<monitoring_ip>:3000` — login: `admin / admin`
- **Prometheus**: `http://<monitoring_ip>:9090` — no auth

To reload Prometheus config without restarting (e.g. after adding a DB VM):

```bash
curl -X POST http://<monitoring_ip>:9090/-/reload
```
