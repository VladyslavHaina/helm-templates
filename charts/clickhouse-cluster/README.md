# ClickHouse Cluster

Production-ready ClickHouse cluster chart built on the Altinity Kubernetes Operator. It deploys a sharded and replicated ClickHouse Installation with Keeper consensus, XML-level users and profiles, quotas, an optional RBAC initialization Job for SQL-level users/roles/row policies, and an optional OpenTelemetry Collector deployment that ingests traces, logs, and metrics directly into ClickHouse tables.

## Architecture

```
                     ┌───────────────────┐
                     │ Altinity Operator  │
                     └─────────┬─────────┘
                               │ manages
          ┌────────────────────┼────────────────────┐
          │                    │                     │
  ┌───────▼────────┐  ┌───────▼──────────┐  ┌──────▼───────┐
  │ ClickHouse     │  │ ClickHouse       │  │ RBAC Job     │
  │ Keeper         │  │ Installation     │  │ (PostSync)   │
  │ (3 replicas)   │  │ (shards x        │  │              │
  │                │  │  replicas)        │  │ SQL users,   │
  │ Raft consensus │  │                  │  │ roles,       │
  │ for replication│  │ HTTP  :8123      │  │ row policies │
  └────────────────┘  │ Native:9000      │  └──────────────┘
                      │ Inter  :9009      │
                      │ Metrics:9363      │
                      └───────┬──────────┘
                              │
                     ┌────────▼─────────┐
                     │ OTEL Collector   │
                     │ (2 replicas)     │
                     │                  │
                     │ OTLP gRPC :4317  │
                     │ OTLP HTTP :4318  │
                     │ Health    :13133 │
                     └──────────────────┘
```

## Features

| Feature | Description | Enabled by |
|---------|-------------|------------|
| Sharded topology | Horizontal scaling across multiple shards | `clickhouse.topology.shards` |
| Replicated topology | High availability with replicas per shard | `clickhouse.topology.replicas` |
| ClickHouse Keeper | Raft-based consensus replacing ZooKeeper | `keeper.enabled` |
| XML users | Admin and extra users created at cluster startup | `clickhouse.users` |
| Query profiles | Configurable memory and execution limits | `clickhouse.profiles` |
| Quotas | Query rate and resource quotas | `clickhouse.quotas` |
| Prometheus metrics | Built-in metrics endpoint for scraping | `clickhouse.prometheus.enabled` |
| SQL RBAC Job | Post-install Job for SQL users, roles, row policies | `rbacJob.enabled` |
| OpenTelemetry Collector | Ingest OTLP traces, logs, and metrics into ClickHouse | `otelCollector.enabled` |
| ServiceMonitor | Prometheus Operator ServiceMonitor for OTEL Collector | `otelCollector.serviceMonitor.enabled` |

## Prerequisites

| Requirement | Minimum Version | Notes |
|-------------|-----------------|-------|
| Kubernetes | 1.26+ | |
| Helm | 3.10+ | |
| Altinity ClickHouse Operator | 0.23+ | [Installation guide](https://github.com/Altinity/clickhouse-operator) |
| Prometheus Operator | -- | Required only if `serviceMonitor.enabled` is true |

## Quick Start

```bash
helm repo add my-charts https://charts.example.com
helm repo update
helm install ch my-charts/clickhouse-cluster -n clickhouse --create-namespace
```

## Examples

| File | Use Case | Features Demonstrated |
|------|----------|----------------------|
| [minimal.yaml](examples/minimal.yaml) | Development / testing | Single shard, 2 replicas, Keeper |
| [production.yaml](examples/production.yaml) | Full production deployment | Multi-shard, OTEL, RBAC, custom profiles |
| [with-rbac-job.yaml](examples/with-rbac-job.yaml) | SQL-level access control | SQL users, roles, grants, row policies |
| [observability-ingest.yaml](examples/observability-ingest.yaml) | Telemetry pipeline | OTEL Collector with batch processing and TTL |

## Configuration Reference

### General

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `cluster.name` | string | `my-clickhouse` | Cluster name used in ClickHouseInstallation |
| `fullnameOverride` | string | `""` | Override the full release name |

### ClickHouse Installation

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `clickhouse.image` | string | `clickhouse/clickhouse-server:24.8` | ClickHouse server image |
| `clickhouse.topology.shards` | int | `1` | Number of shards |
| `clickhouse.topology.replicas` | int | `2` | Replicas per shard |
| `clickhouse.resources.limits.cpu` | string | `"4"` | CPU limit per replica |
| `clickhouse.resources.limits.memory` | string | `8Gi` | Memory limit per replica |
| `clickhouse.resources.requests.cpu` | string | `"1"` | CPU request per replica |
| `clickhouse.resources.requests.memory` | string | `4Gi` | Memory request per replica |
| `clickhouse.storage.data.size` | string | `100Gi` | Data PVC size |
| `clickhouse.storage.data.storageClass` | string | `""` | Storage class for data (empty = cluster default) |
| `clickhouse.storage.logs.size` | string | `20Gi` | Logs PVC size |
| `clickhouse.storage.logs.storageClass` | string | `""` | Storage class for logs |
| `clickhouse.ports.http` | int | `8123` | HTTP interface port |
| `clickhouse.ports.native` | int | `9000` | Native TCP protocol port |
| `clickhouse.ports.interserver` | int | `9009` | Inter-server replication port |
| `clickhouse.ports.metrics` | int | `9363` | Prometheus metrics port |
| `clickhouse.prometheus.enabled` | bool | `true` | Enable Prometheus metrics endpoint |
| `clickhouse.prometheus.endpoint` | string | `/metrics` | Metrics HTTP path |
| `clickhouse.prometheus.port` | int | `9363` | Metrics port |

### ClickHouse Users

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `clickhouse.users.admin.password` | string | `""` | Admin user password (use K8s Secret in production) |
| `clickhouse.users.admin.networks.ip` | list | `["10.0.0.0/8","172.16.0.0/12"]` | Allowed source CIDRs for admin |
| `clickhouse.users.extra` | list | `[]` | Additional XML-level users |
| `clickhouse.users.extra[].name` | string | -- | Username |
| `clickhouse.users.extra[].password` | string | -- | Password |
| `clickhouse.users.extra[].profile` | string | -- | Associated profile name |
| `clickhouse.users.extra[].quota` | string | -- | Associated quota name |
| `clickhouse.users.extra[].networks.ip` | list | -- | Allowed source CIDRs |

### Profiles and Quotas

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `clickhouse.profiles.default.max_memory_usage` | int | `10000000000` | Max memory per query (bytes) |
| `clickhouse.profiles.default.max_execution_time` | int | `300` | Max query execution time (seconds) |
| `clickhouse.profiles.readonly.readonly` | int | `1` | Read-only mode flag |
| `clickhouse.profiles.extra` | list | `[]` | Additional query profiles |
| `clickhouse.quotas.default.interval.duration` | int | `3600` | Quota interval in seconds |
| `clickhouse.quotas.default.interval.queries` | int | `0` | Max queries per interval (0 = unlimited) |
| `clickhouse.quotas.default.interval.errors` | int | `0` | Max errors per interval |
| `clickhouse.quotas.default.interval.result_rows` | int | `0` | Max result rows per interval |
| `clickhouse.quotas.default.interval.read_rows` | int | `0` | Max read rows per interval |
| `clickhouse.quotas.default.interval.execution_time` | int | `0` | Max total execution time per interval |
| `clickhouse.quotas.extra` | list | `[]` | Additional quotas |

### ClickHouse Keeper

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `keeper.enabled` | bool | `true` | Deploy ClickHouse Keeper |
| `keeper.replicas` | int | `3` | Number of Keeper replicas (use odd numbers) |
| `keeper.image` | string | `clickhouse/clickhouse-keeper:24.8` | Keeper image |
| `keeper.resources.limits.cpu` | string | `500m` | CPU limit |
| `keeper.resources.limits.memory` | string | `512Mi` | Memory limit |
| `keeper.resources.requests.cpu` | string | `100m` | CPU request |
| `keeper.resources.requests.memory` | string | `256Mi` | Memory request |
| `keeper.storage.size` | string | `10Gi` | Keeper PVC size |
| `keeper.storage.storageClass` | string | `""` | Storage class |

### RBAC Job

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `rbacJob.enabled` | bool | `false` | Enable post-install RBAC Job |
| `rbacJob.image` | string | `clickhouse/clickhouse-client:24.8` | Client image for SQL execution |
| `rbacJob.users` | list | `[]` | SQL users to create |
| `rbacJob.users[].name` | string | -- | Username |
| `rbacJob.users[].identifiedByEnv` | string | -- | Env var holding the password |
| `rbacJob.roles` | list | `[]` | SQL roles with grants |
| `rbacJob.roles[].name` | string | -- | Role name |
| `rbacJob.roles[].grants` | list | -- | GRANT statements |
| `rbacJob.roles[].users` | list | -- | Users assigned this role |
| `rbacJob.rowPolicies` | list | `[]` | Row-level security policies |
| `rbacJob.rowPolicies[].name` | string | -- | Policy name |
| `rbacJob.rowPolicies[].table` | string | -- | Target table (db.table) |
| `rbacJob.rowPolicies[].condition` | string | -- | SQL WHERE condition |
| `rbacJob.rowPolicies[].users` | list | -- | Users this policy applies to |
| `rbacJob.env` | list | `[]` | Environment variables for secret passwords |
| `rbacJob.syncWave` | string | `"3"` | ArgoCD sync-wave annotation value |

### OpenTelemetry Collector

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `otelCollector.enabled` | bool | `false` | Deploy OTEL Collector |
| `otelCollector.image` | string | `otel/opentelemetry-collector-contrib:0.100.0` | Collector image |
| `otelCollector.replicas` | int | `2` | Number of Collector replicas |
| `otelCollector.resources.limits.cpu` | string | `"1"` | CPU limit |
| `otelCollector.resources.limits.memory` | string | `2Gi` | Memory limit |
| `otelCollector.resources.requests.cpu` | string | `200m` | CPU request |
| `otelCollector.resources.requests.memory` | string | `512Mi` | Memory request |
| `otelCollector.receivers.otlp.grpc.port` | int | `4317` | OTLP gRPC receiver port |
| `otelCollector.receivers.otlp.http.port` | int | `4318` | OTLP HTTP receiver port |
| `otelCollector.processors.batch.timeout` | string | `5s` | Batch timeout |
| `otelCollector.processors.batch.sendBatchSize` | int | `10000` | Batch size |
| `otelCollector.processors.memoryLimiter.limitMib` | int | `1500` | Memory limiter ceiling (MiB) |
| `otelCollector.processors.memoryLimiter.spikeLimitMib` | int | `512` | Spike limit (MiB) |
| `otelCollector.processors.memoryLimiter.checkInterval` | string | `5s` | Check interval |
| `otelCollector.exporter.endpoint` | string | `""` | ClickHouse endpoint (auto-configured if empty) |
| `otelCollector.exporter.database` | string | `otel` | Target database |
| `otelCollector.exporter.logsTableName` | string | `otel_logs` | Logs table name |
| `otelCollector.exporter.tracesTableName` | string | `otel_traces` | Traces table name |
| `otelCollector.exporter.metricsTableName` | string | `otel_metrics` | Metrics table name |
| `otelCollector.exporter.ttl` | string | `72h` | Data retention TTL |
| `otelCollector.exporter.passwordSecretRef.name` | string | `""` | K8s Secret name for ClickHouse password |
| `otelCollector.exporter.passwordSecretRef.key` | string | `""` | Key within the Secret |
| `otelCollector.extensions.healthCheck.port` | int | `13133` | Health check extension port |
| `otelCollector.ports.grpc` | int | `4317` | Service port for gRPC |
| `otelCollector.ports.http` | int | `4318` | Service port for HTTP |
| `otelCollector.ports.health` | int | `13133` | Service port for health check |
| `otelCollector.rbac.enabled` | bool | `true` | Create RBAC resources for Collector |
| `otelCollector.serviceMonitor.enabled` | bool | `false` | Create Prometheus ServiceMonitor |

## How-To Guides

### Scale to 3 shards with 3 replicas each

```yaml
clickhouse:
  topology:
    shards: 3
    replicas: 3
  storage:
    data:
      size: 500Gi
      storageClass: gp3
```

### Create SQL users and roles with the RBAC Job

```yaml
rbacJob:
  enabled: true
  users:
    - name: app_user
      identifiedByEnv: APP_USER_PASSWORD
  roles:
    - name: app_role
      grants:
        - "SELECT, INSERT ON analytics.*"
      users:
        - app_user
  env:
    - name: APP_USER_PASSWORD
      valueFrom:
        secretKeyRef:
          name: clickhouse-users
          key: app-password
```

### Enable the OTEL Collector for observability ingest

```yaml
otelCollector:
  enabled: true
  exporter:
    database: otel
    ttl: "168h"
    passwordSecretRef:
      name: clickhouse-admin
      key: password
```

### Add a read-only user with restricted network access

```yaml
clickhouse:
  users:
    extra:
      - name: readonly_user
        password: ""
        profile: readonly
        quota: default
        networks:
          ip: ["10.0.0.0/8"]
```

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| Replicas fail to join cluster | Keeper is not running or has fewer than 3 nodes | Ensure `keeper.enabled: true` and `keeper.replicas` is an odd number >= 3 |
| `Table is in readonly mode` | Keeper quorum lost | Check Keeper pod logs; restore quorum by scaling replicas back up |
| RBAC Job fails with connection refused | ClickHouse not ready when Job runs | Increase `rbacJob.syncWave` or add an init container wait |
| OTEL Collector restarts in OOMKilled | Memory limiter set too low for ingest rate | Increase `otelCollector.resources.limits.memory` and `memoryLimiter.limitMib` |
| Prometheus shows no ClickHouse metrics | `clickhouse.prometheus.enabled` is false | Set to true and verify the metrics port is not blocked by NetworkPolicy |
| PVC pending | StorageClass does not exist or no capacity | Verify `storageClass` value or leave empty for cluster default |

## Resources Created

| Condition | Resource | API Version |
|-----------|----------|-------------|
| Always | ClickHouseInstallation | clickhouse.altinity.com/v1 |
| `keeper.enabled` | ClickHouseKeeperInstallation | clickhouse-keeper.altinity.com/v1 |
| `rbacJob.enabled` | Job (RBAC init) | batch/v1 |
| `otelCollector.enabled` | Deployment (OTEL Collector) | apps/v1 |
| `otelCollector.enabled` | ConfigMap (OTEL config) | v1 |
| `otelCollector.enabled` | Service (OTEL) | v1 |
| `otelCollector.rbac.enabled` | ServiceAccount, ClusterRole, ClusterRoleBinding | v1 / rbac.authorization.k8s.io/v1 |
| `otelCollector.serviceMonitor.enabled` | ServiceMonitor | monitoring.coreos.com/v1 |
