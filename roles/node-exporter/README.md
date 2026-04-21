# node-exporter Role

Installs [Prometheus node_exporter](https://github.com/prometheus/node_exporter) on an LXD-based Ubuntu 24.04 VM.
Exposes system metrics (CPU, memory, disk, network, load) on port `9100` so the `monitoring` VM's Prometheus can scrape them.

## Requirements

- Ubuntu 24.04 target
- Internet access from the target (to download the binary from GitHub)

## Role Variables

| Variable | Default | Description |
|---|---|---|
| `node_exporter_version` | `1.8.1` | Version to download |
| `node_exporter_port` | `9100` | Port to listen on |
| `node_exporter_user` | `node_exporter` | System user that runs the service |

## Usage

This role is applied automatically by `setup/setup_monitoring.yml` to all hosts in the `[databases]` inventory group.

You can also add it to individual database setup playbooks so node_exporter is deployed at VM creation time:

```yaml
roles:
  - role: node-exporter
  - role: clickhousedb
```

Or run it standalone against all database VMs:

```bash
ansible-playbook setup/setup_monitoring.yml --tags node_exporter
```
