# ClickHouse Helm Chart

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/clickhouse)](https://artifacthub.io/packages/search?repo=clickhouse)
[![Helm](https://img.shields.io/badge/Helm-3+-0F1689?logo=helm&logoColor=white)](https://helm.sh)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.19+-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io)
[![ClickHouse](https://img.shields.io/badge/ClickHouse-26.10-FFCC01?logo=clickhouse&logoColor=black)](https://clickhouse.com)
[![DHI](https://img.shields.io/badge/DHI-optional-2496ED?logo=docker&logoColor=white)](https://docs.docker.com/dhi/)
[![Release](https://img.shields.io/github/v/release/thiagoloureiro/clickhouse.chart?include_prereleases&sort=semver&label=release)](https://github.com/thiagoloureiro/clickhouse.chart/releases)
[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](https://opensource.org/licenses/Apache-2.0)

A Helm chart for deploying ClickHouse on Kubernetes. ClickHouse is an open-source column-oriented database management system capable of real-time generation of analytical data reports using SQL queries.

## Features

- **High Availability**: Supports multi-replica deployments with StatefulSet
- **Persistent Storage**: Configurable persistent volumes for data and logs
- **Metrics & Monitoring**: Built-in Prometheus metrics exporter with optional ServiceMonitor support
- **Web Interface**: Optional Tabix web UI for managing ClickHouse
- **Docker Hardened Images (DHI)**: Optional `dhi.io` images for a smaller, hardened attack surface
- **Flexible Configuration**: Extensive configuration options via values.yaml
- **ZooKeeper / Keeper Support**: Optional ZooKeeper or ClickHouse Keeper for replicated tables
- **Ingress Support**: Configurable ingress for HTTP access
- **Resource Management**: Configurable resource limits and requests

## Chart Details

| | |
|---|---|
| **Chart Version** | `26.12` |
| **App Version** | `26.10.3.7` |
| **Default Image** | `clickhouse/clickhouse-server:26.10.3.7` |
| **DHI Image** | `dhi.io/clickhouse-server:26.10` |
| **Maintainer** | thiagoloureiro |

## Installation

### Add the Helm repository

```bash
helm repo add clickhouse https://thiagoloureiro.github.io/clickhouse.chart/
helm repo update
```

### Install the chart

```bash
helm install my-clickhouse clickhouse/clickhouse
```

### Install with custom values

```bash
helm install my-clickhouse clickhouse/clickhouse -f my-values.yaml
```

## Configuration

The following table lists the most important configurable parameters and their default values:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `clickhouse.replicas` | Number of ClickHouse shards | `3` |
| `clickhouse.image` | ClickHouse image | `clickhouse/clickhouse-server` |
| `clickhouse.imageVersion` | ClickHouse image version | `26.10.3.7` |
| `clickhouse.dhi.enabled` | Use Docker Hardened Images from `dhi.io` | `false` |
| `clickhouse.dhi.image` | DHI image repository | `dhi.io/clickhouse-server` |
| `clickhouse.dhi.imageVersion` | DHI image tag | `26.10` |
| `clickhouse.imagePullSecrets` | Registry pull secrets (required when DHI is enabled) | `[]` |
| `clickhouse.configmap.keeper.enabled` | Deploy ClickHouse Keeper (required for Replicated* sync) | `false` |
| `clickhouse.configmap.remote_servers.internal_replication` | Distributed writes one replica; Replicated* syncs | `true` |
| `clickhouse.configmap.remote_servers.replica.backup.enabled` | Second StatefulSet per shard (`clickhouse-replica-*`) | `false` |
| `clickhouse.persistentVolumeClaim.enabled` | Enable persistent volumes | `true` |
| `clickhouse.persistentVolumeClaim.dataPersistentVolume.storage` | Data volume size | `100Gi` |
| `clickhouse.metrics.enabled` | Enable Prometheus metrics | `true` |
| `clickhouse.metrics.port` | Metrics port | `9116` |
| `tabix.enabled` | Enable Tabix web UI | `false` |
| `timezone` | Timezone for the cluster | `UTC` |

For a complete list of configuration options, see [values.yaml](clickhouse/values.yaml).

## Docker Hardened Images (DHI)

By default the chart uses the official ClickHouse image. To switch to [Docker Hardened Images](https://docs.docker.com/dhi/), enable DHI and provide an `imagePullSecrets` entry authenticated against `dhi.io`.

```bash
# Create a pull secret for dhi.io (Docker Hub credentials work)
kubectl create secret docker-registry dhi-registry \
  --docker-server=dhi.io \
  --docker-username=<DOCKER_USER> \
  --docker-password=<DOCKER_PAT>
```

```bash
helm install clickhouse clickhouse/clickhouse \
  --set clickhouse.dhi.enabled=true \
  --set clickhouse.imagePullSecrets[0]=dhi-registry
```

Or in values:

```yaml
clickhouse:
  dhi:
    enabled: true
  imagePullSecrets:
    - dhi-registry
```

When `dhi.enabled` is `true`, ClickHouse and Keeper pods pull `dhi.io/clickhouse-server:26.10`. Install fails if `imagePullSecrets` is empty.

## Replication / HA

Cluster membership alone does **not** sync table data. For real replica sync:

1. Enable Keeper (or external ZooKeeper)
2. Enable the backup StatefulSet (`remote_servers.replica.backup.enabled`)
3. Keep `internal_replication: true` (default)
4. Create tables with `ReplicatedMergeTree` (or similar) using `{shard}` / `{replica}` macros

```bash
helm install clickhouse clickhouse/clickhouse \
  --set clickhouse.configmap.keeper.enabled=true \
  --set clickhouse.configmap.remote_servers.replica.backup.enabled=true
```

Example table:

```sql
CREATE TABLE events ON CLUSTER '{cluster}'
(
  id UInt64,
  ts DateTime
)
ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/events', '{replica}')
PARTITION BY toYYYYMM(ts)
ORDER BY (id, ts);
```

Macros `{cluster}`, `{shard}`, and `{replica}` are injected automatically (`cluster` = release fullname).

## Examples

### Basic Installation

```bash
helm install clickhouse clickhouse/clickhouse
```

### Installation with Custom Replicas

```bash
helm install clickhouse clickhouse/clickhouse \
  --set clickhouse.replicas=5
```

### Installation with Tabix UI

```bash
helm install clickhouse clickhouse/clickhouse \
  --set tabix.enabled=true
```

### Installation with Custom Storage

```bash
helm install clickhouse clickhouse/clickhouse \
  --set clickhouse.persistentVolumeClaim.dataPersistentVolume.storage=500Gi
```

### Installation with Prometheus ServiceMonitor

```bash
helm install clickhouse clickhouse/clickhouse \
  --set clickhouse.metrics.serviceMonitor.enabled=true
```

## Accessing ClickHouse

### HTTP Interface

The HTTP interface is available on port `8123`:

```bash
# Port forward to access locally
kubectl port-forward svc/clickhouse 8123:8123

# Query via HTTP
curl 'http://localhost:8123/?query=SELECT%201'
```

### Native TCP Interface

The native TCP interface is available on port `9000`:

```bash
# Port forward to access locally
kubectl port-forward svc/clickhouse 9000:9000
```

### Tabix Web UI

If Tabix is enabled, you can access it via port forwarding or ingress:

```bash
# Port forward to access locally
kubectl port-forward svc/clickhouse-tabix 8080:80
```

Then open `http://localhost:8080` in your browser.

## Upgrading

```bash
helm upgrade clickhouse clickhouse/clickhouse
```

## Uninstalling

```bash
helm uninstall clickhouse
```

**Note**: This will delete all resources including persistent volumes. Make sure to backup your data before uninstalling.

## Development

### Building and Publishing

To create a new version of the chart:

```bash
./create-version.sh
```

This script will:
1. Package the Helm chart
2. Update the repository index
3. Prepare the chart for publishing to GitHub Pages

## Resources

- [ClickHouse Documentation](https://clickhouse.com/docs/)
- [ClickHouse GitHub](https://github.com/ClickHouse/ClickHouse)
- [Docker Hardened Images](https://docs.docker.com/dhi/)
- [Helm Documentation](https://helm.sh/docs/)

## License

This Helm chart is provided as-is. Please refer to the ClickHouse license for the database software itself.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Support

For issues and questions, please open an issue on the [GitHub repository](https://github.com/thiagoloureiro/clickhouse.chart).
