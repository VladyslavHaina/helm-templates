# Observability Stack

Production-ready observability pipeline built around the OpenTelemetry Collector with pluggable storage backends (ClickHouse, Elasticsearch, or OTLP forwarding) and a dashboard UI (HyperDX or Grafana). The chart deploys an OTEL Collector fleet that receives traces, logs, and metrics over OTLP gRPC/HTTP, applies batching and memory-limiting processors, and exports to one or more backends. An optional MongoDB StatefulSet provides the metadata store required by HyperDX.

## Architecture

```
  Applications              K8s Cluster
      |                         |
      | OTLP gRPC/HTTP          | k8s_cluster / k8s_objects
      v                         v
  +----------------------------------+
  |     OpenTelemetry Collector      |
  |  receivers -> processors ->      |
  |  exporters                       |
  +------+----------+----------+-----+
         |          |          |
    +----+---+ +----+---+ +---+----+
    |ClickHouse| |  ES/OS | | OTLP  |
    | exporter | |exporter| |forward |
    +----+-----+ +--------+ +-------+
         |
         v
  +--------------+
  |  ClickHouse  |  (external)
  +--------------+
         |
         v
  +--------------+      +-----------+
  |   HyperDX    |----->|  MongoDB  |
  |   (Web UI)   |      | (metadata)|
  +--------------+      +-----------+
         |
  +--------------+
  |   Ingress /  |
  |   Istio VS   |
  +--------------+
```

## Features

| Feature | Description | Enabled by |
|---------|-------------|------------|
| OTEL Collector | Receives, processes, and exports telemetry via OTLP gRPC/HTTP | `otelCollector.enabled: true` |
| K8s receivers | Cluster metrics and object watching from the API server | `receivers.k8sCluster.enabled` / `receivers.k8sObjects.enabled` |
| Batch + memory limiter | Efficient batching with OOM protection | `processors.batch.*` / `processors.memoryLimiter.*` |
| ClickHouse exporter | Traces, logs, and metrics to ClickHouse | `exporters.clickhouse.enabled: true` |
| Elasticsearch exporter | Traces and logs to Elasticsearch/OpenSearch | `exporters.elasticsearch.enabled: true` |
| OTLP forwarding | Forward telemetry to a remote OTLP endpoint | `exporters.otlp.enabled: true` |
| HyperDX / Grafana UI | Observability dashboard with pluggable backend | `ui.type: hyperdx` or `ui.type: grafana` |
| MongoDB metadata store | Persistent metadata backend for HyperDX | `mongodb.enabled: true` |
| Ingress / Istio | Expose UI via Ingress or Istio VirtualService | `ingress.enabled` / `istio.enabled` |
| PDB + ServiceMonitor | Availability guarantees and Prometheus scraping | `podDisruptionBudget.enabled` / `serviceMonitor.enabled` |

## Prerequisites

| Requirement | Minimum Version | Notes |
|-------------|----------------|-------|
| Kubernetes | 1.24+ | RBAC and PDB support required |
| Helm | 3.10+ | OCI registry support recommended |

| Optional Dependency | Purpose |
|---------------------|---------|
| ClickHouse cluster | Traces, logs, and metrics storage backend |
| Elasticsearch / OpenSearch | Alternative traces and logs backend |
| Prometheus Operator | ServiceMonitor auto-discovery for collector metrics |
| cert-manager | TLS certificates for Ingress |
| Istio | VirtualService-based routing |

## Quick Start

```bash
helm repo add observability-stack ./charts/observability-stack
helm install observability ./charts/observability-stack -n observability --create-namespace
helm status observability -n observability
```

## Examples

| File | Use Case | Features Demonstrated |
|------|----------|----------------------|
| [clickhouse-hyperdx.yaml](examples/clickhouse-hyperdx.yaml) | Full stack with ClickHouse + HyperDX | ClickHouse exporter, HyperDX UI, MongoDB |
| [clickhouse-minimal.yaml](examples/clickhouse-minimal.yaml) | Collector + ClickHouse only | ClickHouse exporter, no UI |
| [elasticsearch.yaml](examples/elasticsearch.yaml) | Elasticsearch backend | Elasticsearch exporter, log and trace indexing |
| [collector-only.yaml](examples/collector-only.yaml) | OTEL Collector forwarding | OTLP exporter, no local storage |

## Configuration Reference

### Stack Metadata

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `stack.name` | string | `observability` | Name prefix for all resources |
| `fullnameOverride` | string | `""` | Override the full resource name |

### OTEL Collector

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `otelCollector.enabled` | bool | `true` | Deploy the OpenTelemetry Collector |
| `otelCollector.image` | string | `otel/opentelemetry-collector-contrib:0.100.0` | Collector container image |
| `otelCollector.replicas` | int | `2` | Number of collector replicas |
| `otelCollector.resources.limits.cpu` | string | `"1"` | CPU limit |
| `otelCollector.resources.limits.memory` | string | `2Gi` | Memory limit |
| `otelCollector.resources.requests.cpu` | string | `200m` | CPU request |
| `otelCollector.resources.requests.memory` | string | `512Mi` | Memory request |

### Receivers

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `otelCollector.receivers.otlp.grpc.port` | int | `4317` | OTLP gRPC receiver port |
| `otelCollector.receivers.otlp.http.port` | int | `4318` | OTLP HTTP receiver port |
| `otelCollector.receivers.k8sCluster.enabled` | bool | `false` | Enable k8s_cluster receiver |
| `otelCollector.receivers.k8sCluster.collectionInterval` | string | `30s` | Cluster metrics collection interval |
| `otelCollector.receivers.k8sObjects.enabled` | bool | `false` | Enable k8s_objects receiver |
| `otelCollector.receivers.k8sObjects.objects` | list | `[{name: events, mode: watch}]` | Kubernetes objects to watch |

### Processors

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `otelCollector.processors.batch.timeout` | string | `5s` | Maximum time before a batch is sent |
| `otelCollector.processors.batch.sendBatchSize` | int | `10000` | Number of items per batch |
| `otelCollector.processors.memoryLimiter.limitMib` | int | `1500` | Hard memory limit in MiB |
| `otelCollector.processors.memoryLimiter.spikeLimitMib` | int | `512` | Spike limit in MiB |
| `otelCollector.processors.memoryLimiter.checkInterval` | string | `5s` | Memory check interval |
| `otelCollector.processors.resource.enabled` | bool | `false` | Enable the resource processor |
| `otelCollector.processors.resource.attributes` | list | `[]` | Resource attributes to add/modify |

### Exporters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `otelCollector.exporters.clickhouse.enabled` | bool | `true` | Enable ClickHouse exporter |
| `otelCollector.exporters.clickhouse.endpoint` | string | `""` | ClickHouse connection endpoint |
| `otelCollector.exporters.clickhouse.database` | string | `otel` | Target database name |
| `otelCollector.exporters.clickhouse.logsTableName` | string | `otel_logs` | Logs table name |
| `otelCollector.exporters.clickhouse.tracesTableName` | string | `otel_traces` | Traces table name |
| `otelCollector.exporters.clickhouse.metricsTableName` | string | `otel_metrics` | Metrics table name |
| `otelCollector.exporters.clickhouse.ttl` | string | `"72h"` | Data retention TTL |
| `otelCollector.exporters.clickhouse.passwordSecretRef.name` | string | `""` | Secret containing ClickHouse password |
| `otelCollector.exporters.clickhouse.passwordSecretRef.key` | string | `""` | Key within the password Secret |
| `otelCollector.exporters.elasticsearch.enabled` | bool | `false` | Enable Elasticsearch exporter |
| `otelCollector.exporters.elasticsearch.endpoints` | list | `[]` | Elasticsearch endpoint URLs |
| `otelCollector.exporters.elasticsearch.index` | string | `otel` | Index prefix |
| `otelCollector.exporters.otlp.enabled` | bool | `false` | Enable OTLP forwarding exporter |
| `otelCollector.exporters.otlp.endpoint` | string | `""` | Remote OTLP endpoint |
| `otelCollector.exporters.logging.enabled` | bool | `false` | Enable debug logging exporter |
| `otelCollector.exporters.logging.verbosity` | string | `detailed` | Log verbosity level |

### Extensions

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `otelCollector.extensions.healthCheck.port` | int | `13133` | Health check extension port |
| `otelCollector.extensions.zpages.enabled` | bool | `false` | Enable zPages debugging extension |
| `otelCollector.extensions.zpages.port` | int | `55679` | zPages port |

### Collector Ports

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `otelCollector.ports.grpc` | int | `4317` | Service port for OTLP gRPC |
| `otelCollector.ports.http` | int | `4318` | Service port for OTLP HTTP |
| `otelCollector.ports.health` | int | `13133` | Service port for health checks |
| `otelCollector.ports.metrics` | int | `8888` | Service port for self-metrics |

### Collector Operations

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `otelCollector.rbac.enabled` | bool | `true` | Create RBAC resources for K8s metadata access |
| `otelCollector.serviceMonitor.enabled` | bool | `false` | Create a Prometheus ServiceMonitor |
| `otelCollector.serviceMonitor.interval` | string | `30s` | Prometheus scrape interval |
| `otelCollector.podDisruptionBudget.enabled` | bool | `true` | Create a PodDisruptionBudget |
| `otelCollector.podDisruptionBudget.minAvailable` | int | `1` | Minimum available pods during disruption |

### UI Dashboard

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ui.type` | string | `hyperdx` | Dashboard type: `hyperdx`, `grafana`, or `none` |

### HyperDX

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ui.hyperdx.enabled` | bool | `true` | Deploy HyperDX |
| `ui.hyperdx.image` | string | `hyperdx/hyperdx:latest` | HyperDX container image |
| `ui.hyperdx.replicas` | int | `2` | Number of HyperDX replicas |
| `ui.hyperdx.resources.limits.cpu` | string | `"1"` | CPU limit |
| `ui.hyperdx.resources.limits.memory` | string | `2Gi` | Memory limit |
| `ui.hyperdx.resources.requests.cpu` | string | `200m` | CPU request |
| `ui.hyperdx.resources.requests.memory` | string | `512Mi` | Memory request |
| `ui.hyperdx.service.port` | int | `8080` | HyperDX service port |
| `ui.hyperdx.apiKey` | string | `""` | HyperDX API key |
| `ui.hyperdx.appUrl` | string | `""` | Application URL for HyperDX |
| `ui.hyperdx.frontendUrl` | string | `""` | Frontend URL for HyperDX |
| `ui.hyperdx.probes.liveness.path` | string | `/health` | Liveness probe path |
| `ui.hyperdx.probes.liveness.port` | int | `8080` | Liveness probe port |
| `ui.hyperdx.probes.readiness.path` | string | `/health` | Readiness probe path |
| `ui.hyperdx.probes.readiness.port` | int | `8080` | Readiness probe port |
| `ui.hyperdx.podDisruptionBudget.enabled` | bool | `true` | Create a PDB for HyperDX |
| `ui.hyperdx.podDisruptionBudget.minAvailable` | int | `1` | Minimum available HyperDX pods |

### Grafana

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ui.grafana.enabled` | bool | `false` | Deploy Grafana (use subchart or external) |

### MongoDB

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `mongodb.enabled` | bool | `false` | Deploy MongoDB for HyperDX metadata |
| `mongodb.image` | string | `mongo:7.0` | MongoDB container image |
| `mongodb.port` | int | `27017` | MongoDB service port |
| `mongodb.storage.size` | string | `20Gi` | Persistent volume size |
| `mongodb.storage.storageClass` | string | `""` | StorageClass (empty = default) |
| `mongodb.resources.limits.cpu` | string | `"1"` | CPU limit |
| `mongodb.resources.limits.memory` | string | `2Gi` | Memory limit |
| `mongodb.resources.requests.cpu` | string | `200m` | CPU request |
| `mongodb.resources.requests.memory` | string | `512Mi` | Memory request |

### Ingress

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ingress.enabled` | bool | `false` | Create a Kubernetes Ingress |
| `ingress.className` | string | `""` | Ingress class name |
| `ingress.annotations` | object | `{}` | Ingress annotations |
| `ingress.hosts` | list | `[]` | Ingress host rules |
| `ingress.tls` | list | `[]` | TLS configuration blocks |

### Istio

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `istio.enabled` | bool | `false` | Create an Istio VirtualService |
| `istio.virtualService.hosts` | list | `[]` | VirtualService hostnames |
| `istio.virtualService.gateways` | list | `[]` | Istio Gateway references |

### Scheduling

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `scheduling.nodeSelector` | object | `{}` | Node selector labels |
| `scheduling.tolerations` | list | `[]` | Pod tolerations |

### Security

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `podSecurityContext.runAsNonRoot` | bool | `true` | Enforce non-root container execution |
| `podSecurityContext.seccompProfile.type` | string | `RuntimeDefault` | Seccomp profile type |

### Network Policy

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `networkPolicy.enabled` | bool | `false` | Create a Kubernetes NetworkPolicy |

## How-To Guides

### Deploy a full ClickHouse + HyperDX stack

```yaml
otelCollector:
  exporters:
    clickhouse:
      enabled: true
      endpoint: "tcp://clickhouse.infra:9000"
      ttl: "168h"
      passwordSecretRef: { name: clickhouse-credentials, key: password }
ui:
  type: hyperdx
  hyperdx: { enabled: true, appUrl: "https://obs.example.com" }
mongodb:
  enabled: true
```

### Forward telemetry to a remote OTLP endpoint

```yaml
otelCollector:
  exporters:
    clickhouse: { enabled: false }
    otlp: { enabled: true, endpoint: "https://collector.vendor.io:4317" }
ui:
  type: none
```

### Add cluster-level K8s metrics

```yaml
otelCollector:
  receivers:
    k8sCluster: { enabled: true, collectionInterval: 15s }
    k8sObjects:
      enabled: true
      objects:
        - { name: events, mode: watch }
        - { name: pods, mode: pull }
  rbac: { enabled: true }
```

### Expose the UI with Ingress and TLS

```yaml
ingress:
  enabled: true
  className: nginx
  hosts:
    - host: obs.example.com
      paths: [{ path: /, pathType: Prefix }]
  tls:
    - secretName: obs-tls
      hosts: [obs.example.com]
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
```

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Collector pods in CrashLoopBackOff | Memory limit too low for batch size | Increase `otelCollector.resources.limits.memory` or reduce `processors.batch.sendBatchSize` |
| No data in ClickHouse | Endpoint not set or unreachable | Verify `exporters.clickhouse.endpoint` and network connectivity |
| HyperDX shows "No data" | MongoDB not deployed or ClickHouse misconfigured | Enable `mongodb.enabled: true` and verify ClickHouse exporter settings |
| OTLP gRPC connection refused | Collector service port mismatch | Confirm `otelCollector.ports.grpc` matches client configuration |
| ServiceMonitor not discovered | Prometheus Operator missing or label mismatch | Install Prometheus Operator and check ServiceMonitor labels |
| PDB blocking rollout | `minAvailable` equals `replicas` | Set `podDisruptionBudget.minAvailable` lower than `replicas` |
| K8s receiver returns empty data | RBAC not enabled | Set `otelCollector.rbac.enabled: true` |

## Resources Created

| Condition | Resource | API Version |
|-----------|----------|-------------|
| `otelCollector.enabled: true` | Deployment (OTEL Collector) | `apps/v1` |
| `otelCollector.enabled: true` | ConfigMap (collector config) | `v1` |
| `otelCollector.enabled: true` | Service (collector) | `v1` |
| `otelCollector.rbac.enabled: true` | ClusterRole, ClusterRoleBinding, ServiceAccount | `rbac.authorization.k8s.io/v1`, `v1` |
| `otelCollector.podDisruptionBudget.enabled: true` | PodDisruptionBudget | `policy/v1` |
| `ui.hyperdx.enabled: true` | Deployment (HyperDX) | `apps/v1` |
| `mongodb.enabled: true` | StatefulSet (MongoDB) | `apps/v1` |
| `otelCollector.serviceMonitor.enabled: true` | ServiceMonitor | `monitoring.coreos.com/v1` |
| `ingress.enabled: true` | Ingress | `networking.k8s.io/v1` |
| `istio.enabled: true` | VirtualService | `networking.istio.io/v1beta1` |
