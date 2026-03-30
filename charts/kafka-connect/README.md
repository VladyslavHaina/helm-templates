# Kafka Connect

Production-ready Kafka Connect chart for Confluent Platform that deploys a distributed Connect cluster with automatic connector plugin installation, declarative connector deployment, SASL/SSL security, OTEL and JMX observability agents, a connector health monitoring sidecar with auto-restart, HPA, PDB, and Istio integration.

## Architecture

```
  ┌─────────────────────────────────────────────────────────────────┐
  │  Kafka Connect Pod                                              │
  │                                                                 │
  │  Init Containers (sequential)                                   │
  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
  │  │ Install      │  │ Download     │  │ Download     │         │
  │  │ Plugins      │→ │ OTEL Agent   │→ │ JMX Exporter │         │
  │  │ (confluent-  │  │ (optional)   │  │ (optional)   │         │
  │  │  hub / wget) │  └──────────────┘  └──────────────┘         │
  │  └──────────────┘                                              │
  │                                                                 │
  │  Containers                                                     │
  │  ┌────────────────────────────────────┐  ┌──────────────────┐  │
  │  │ Kafka Connect Worker              │  │ Connector Monitor │  │
  │  │  REST API :8083                   │  │ (sidecar)         │  │
  │  │  JMX Metrics :9404                │  │ health check +    │  │
  │  │  OTEL Traces → collector          │  │ auto-restart      │  │
  │  │                                    │  └──────────────────┘  │
  │  │  Loaded plugins:                   │                        │
  │  │   /usr/share/java (built-in)      │                        │
  │  │   /usr/share/confluent-hub-*      │                        │
  │  │   /opt/plugins (init container)   │                        │
  │  └────────────────────────────────────┘                        │
  └───────────────────────────┬────────────────────────────────────┘
                              │
              ┌───────────────▼───────────────┐
              │       Kafka Brokers           │
              │  connect-configs / offsets /   │
              │  status (internal topics)      │
              └───────────────┬───────────────┘
                   ┌──────────┼──────────┐
                   ▼          ▼          ▼
              ┌────────┐ ┌────────┐ ┌────────┐
              │ Source  │ │ Source │ │ Sink   │
              │ DB(CDC) │ │ API   │ │ S3/SF/ │
              └────────┘ └────────┘ │ JDBC   │
                                    └────────┘

  Post-install:
  ┌──────────────────────────────┐
  │ Connector Deploy Job         │
  │ (Helm hook: post-install)    │
  │ Waits for REST API → submits │
  │ connector configs via PUT    │
  └──────────────────────────────┘
```

## Features

| Feature | Description | Enabled by |
|---------|-------------|------------|
| Distributed workers | Scalable Connect cluster with configurable group ID | `replicaCount` / `connect.groupId` |
| Plugin installation | Install connectors via Confluent Hub or direct download at startup | `plugins.enabled` |
| Connector deployment | Auto-submit connector configs to REST API via post-install Job | `connectorDeployJob.enabled` |
| SASL/SSL security | PLAINTEXT, SSL, SASL_PLAINTEXT, SASL_SSL protocols | `kafka.securityProtocol` |
| Schema Registry | Avro/Protobuf/JSON Schema support | `schemaRegistry.enabled` |
| OTEL Java Agent | Distributed tracing via OpenTelemetry init container | `otelAgent.enabled` |
| JMX Prometheus Exporter | Kafka Connect metrics for Prometheus | `jmxExporter.enabled` |
| Connector Monitor | Sidecar that checks connector health and auto-restarts failed tasks | `connectorMonitor.enabled` |
| HPA autoscaling | Scale workers based on CPU/memory utilization | `autoscaling.enabled` |
| Pod Disruption Budget | Guarantee minimum available replicas during disruptions | `podDisruptionBudget.enabled` |
| Istio VirtualService | Service mesh traffic routing | `istio.enabled` |
| ServiceMonitor | Prometheus Operator scraping integration | `serviceMonitor.enabled` |
| Network Policy | Restrict pod network traffic | `networkPolicy.enabled` |
| CSI Secrets | Mount secrets from cloud providers via CSI driver | `secrets.csi.enabled` |

## Connector Plugin Lifecycle

Installing and running a connector involves three steps, all managed from `values.yaml`:

```
Step 1: plugins.enabled          → Init container installs plugin JARs
Step 2: connectors[]             → Connector configs defined in values
Step 3: connectorDeployJob       → Post-install Job submits configs to REST API
```

### Supported Plugin Sources

| Source | Method | Example |
|--------|--------|---------|
| Confluent Hub | `plugins.confluentHub[]` | Debezium, S3 Sink, JDBC, Snowflake |
| Direct download | `plugins.directDownload[]` | Custom JARs, Maven artifacts, GitHub releases |
| Pre-built image | `image.repository` | Build custom Docker image with plugins baked in |

### Supported Connectors (examples in values.yaml)

| Connector | Type | Plugin Owner |
|-----------|------|-------------|
| Debezium MongoDB | CDC Source | `debezium/debezium-connector-mongodb` |
| Debezium PostgreSQL | CDC Source | `debezium/debezium-connector-postgresql` |
| Debezium MySQL | CDC Source | `debezium/debezium-connector-mysql` |
| S3 Sink | Sink | `confluentinc/kafka-connect-s3` |
| Snowflake Sink | Sink | `snowflakeinc/snowflake-kafka-connector` |
| JDBC Sink/Source | Both | `confluentinc/kafka-connect-jdbc` |

## Prerequisites

| Requirement | Minimum Version | Notes |
|-------------|-----------------|-------|
| Kubernetes | 1.24+ | |
| Helm | 3.10+ | |
| Kafka cluster | -- | Accessible via `kafka.bootstrapServers` |

| Optional Dependency | Purpose |
|---------------------|---------|
| Prometheus Operator | ServiceMonitor auto-discovery (`serviceMonitor.enabled`) |
| Secrets Store CSI Driver | Cloud secrets mounting (`secrets.csi.enabled`) |
| Istio | VirtualService routing (`istio.enabled`) |

## Quick Start

```bash
# Minimal Connect cluster
helm install connect ./charts/kafka-connect \
  --set kafka.bootstrapServers=kafka:9092

# With a values file
helm install connect ./charts/kafka-connect -f my-values.yaml

# Dry run to inspect output
helm template connect ./charts/kafka-connect -f my-values.yaml
```

## Examples

| File | Use Case | Features Demonstrated |
|------|----------|----------------------|
| [basic.yaml](examples/basic.yaml) | Minimal Connect cluster | Default worker settings, PDB |
| [debezium-cdc.yaml](examples/debezium-cdc.yaml) | MongoDB CDC pipeline | Plugin install, connector deploy Job, Debezium, monitor sidecar |
| [s3-sink.yaml](examples/s3-sink.yaml) | S3 data lake archive | S3 Sink with Parquet, time partitioning, IRSA |
| [snowflake-sink.yaml](examples/snowflake-sink.yaml) | Stream to Snowflake | Snowflake Sink with buffering, secret injection |
| [multi-connector-pipeline.yaml](examples/multi-connector-pipeline.yaml) | CDC + S3 + JDBC on one cluster | 3 plugins, 3 connectors, OTEL, JMX, HPA |
| [production.yaml](examples/production.yaml) | Full production deployment | OTEL, JMX, HPA, SASL_SSL, monitor sidecar |
| [with-schema-registry.yaml](examples/with-schema-registry.yaml) | Avro serialization | Schema Registry, Avro converters |

## Configuration Reference

### General

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `app.name` | string | `kafka-connect` | Application name label |
| `fullnameOverride` | string | `""` | Override the full release name |

### Image

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `image.repository` | string | `confluentinc/cp-kafka-connect` | Container image repository |
| `image.tag` | string | `"7.7.0"` | Image tag |
| `image.pullPolicy` | string | `IfNotPresent` | Pull policy |
| `image.pullSecrets` | list | `[]` | Image pull secret references |

### Replicas and Resources

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `replicaCount` | int | `2` | Number of Connect worker replicas |
| `resources.limits.cpu` | string | `"2"` | CPU limit |
| `resources.limits.memory` | string | `4Gi` | Memory limit |
| `resources.requests.cpu` | string | `500m` | CPU request |
| `resources.requests.memory` | string | `2Gi` | Memory request |

### Kafka Cluster

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `kafka.bootstrapServers` | string | `kafka-bootstrap:9092` | Kafka broker addresses |
| `kafka.securityProtocol` | string | `PLAINTEXT` | Security protocol (PLAINTEXT/SSL/SASL_PLAINTEXT/SASL_SSL) |
| `kafka.sasl.mechanism` | string | `SCRAM-SHA-512` | SASL mechanism |
| `kafka.sasl.jaasConfig` | string | `""` | Inline JAAS configuration |
| `kafka.sasl.credentialsSecret.name` | string | `""` | K8s Secret name for SASL credentials |
| `kafka.sasl.credentialsSecret.usernameKey` | string | `username` | Key for username in the Secret |
| `kafka.sasl.credentialsSecret.passwordKey` | string | `password` | Key for password in the Secret |

### Connect Worker

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `connect.groupId` | string | `connect-cluster` | Consumer group ID for workers |
| `connect.configStorageTopic` | string | `connect-configs` | Topic for connector configs |
| `connect.offsetStorageTopic` | string | `connect-offsets` | Topic for connector offsets |
| `connect.statusStorageTopic` | string | `connect-status` | Topic for connector status |
| `connect.configStorageReplicationFactor` | int | `3` | Replication factor for config topic |
| `connect.offsetStorageReplicationFactor` | int | `3` | Replication factor for offset topic |
| `connect.statusStorageReplicationFactor` | int | `3` | Replication factor for status topic |
| `connect.keyConverter` | string | `...JsonConverter` | Key converter class |
| `connect.valueConverter` | string | `...JsonConverter` | Value converter class |
| `connect.keyConverterSchemasEnabled` | bool | `false` | Enable schemas in key converter |
| `connect.valueConverterSchemasEnabled` | bool | `false` | Enable schemas in value converter |
| `connect.pluginPath` | string | `/usr/share/java,...` | Plugin discovery path (auto-appends `/opt/plugins` when `plugins.enabled`) |
| `connect.restPort` | int | `8083` | REST API port |
| `connect.extraConfig` | map | `{}` | Additional worker properties (`key: value` mapped to `CONNECT_` env vars) |

### Schema Registry

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `schemaRegistry.enabled` | bool | `false` | Enable Schema Registry integration |
| `schemaRegistry.url` | string | `""` | Schema Registry URL |

### Connector Plugins

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `plugins.enabled` | bool | `false` | Enable plugin installation via init container |
| `plugins.confluentHub` | list | `[]` | Plugins to install from Confluent Hub |
| `plugins.confluentHub[].name` | string | - | Plugin name (e.g., `debezium-connector-mongodb`) |
| `plugins.confluentHub[].owner` | string | - | Plugin owner (e.g., `debezium`, `confluentinc`) |
| `plugins.confluentHub[].version` | string | - | Plugin version (e.g., `"2.5.4"`) |
| `plugins.directDownload` | list | `[]` | JARs/archives to download directly |
| `plugins.directDownload[].url` | string | - | Download URL |
| `plugins.directDownload[].type` | string | - | File type: `jar`, `tgz`, or `zip` |

### Connectors

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `connectors` | list | `[]` | Connector configurations to deploy |
| `connectors[].name` | string | - | Connector name (unique identifier) |
| `connectors[].config` | map | - | Full connector configuration (passed to REST API) |

### Connector Deploy Job

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `connectorDeployJob.enabled` | bool | `false` | Enable post-install Job to submit connectors |
| `connectorDeployJob.image` | string | `curlimages/curl:8.7.1` | Job container image |
| `connectorDeployJob.waitTimeoutSeconds` | int | `300` | Max wait for Connect REST API readiness |
| `connectorDeployJob.backoffSeconds` | int | `5` | Backoff between readiness retries |

### JVM

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `jvm.heapSize` | string | `2g` | JVM heap size (-Xms/-Xmx) |
| `jvm.opts` | string | `""` | Additional JVM options |
| `jvm.gcOpts` | string | `-XX:+UseG1GC -XX:MaxGCPauseMillis=200` | GC tuning flags |

### OTEL Java Agent

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `otelAgent.enabled` | bool | `false` | Enable OTEL Java agent init container |
| `otelAgent.image` | string | `busybox:1.36` | Init container image for download |
| `otelAgent.version` | string | `"2.4.0"` | OTEL Java agent version |
| `otelAgent.endpoint` | string | `http://otel-collector:4317` | OTEL collector endpoint |
| `otelAgent.serviceName` | string | `kafka-connect` | Service name for traces |
| `otelAgent.samplingRatio` | string | `"0.1"` | Trace sampling ratio (0.0-1.0) |
| `otelAgent.propagators` | string | `tracecontext,baggage` | Context propagators |

### JMX Prometheus Exporter

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `jmxExporter.enabled` | bool | `false` | Enable JMX exporter init container |
| `jmxExporter.image` | string | `busybox:1.36` | Init container image for download |
| `jmxExporter.version` | string | `"1.0.1"` | JMX exporter version |
| `jmxExporter.port` | int | `9404` | Metrics port |
| `jmxExporter.rules` | list | see values.yaml | Prometheus scraping rules for Connect metrics |

### Connector Monitor

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `connectorMonitor.enabled` | bool | `false` | Enable health monitoring sidecar |
| `connectorMonitor.image` | string | `curlimages/curl:8.7.1` | Sidecar image |
| `connectorMonitor.intervalSeconds` | int | `30` | Health check interval |
| `connectorMonitor.autoRestart` | bool | `true` | Auto-restart failed connector tasks |

### Autoscaling

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `autoscaling.enabled` | bool | `false` | Enable HPA |
| `autoscaling.minReplicas` | int | `2` | Minimum replicas |
| `autoscaling.maxReplicas` | int | `6` | Maximum replicas |
| `autoscaling.targetCPUUtilizationPercentage` | int | `70` | CPU target for scaling |
| `autoscaling.targetMemoryUtilizationPercentage` | int | `75` | Memory target for scaling |

### Pod Disruption Budget

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `podDisruptionBudget.enabled` | bool | `true` | Create a PDB |
| `podDisruptionBudget.minAvailable` | int | `1` | Minimum available pods |

### Health Probes

| Parameter | Type | Liveness Default | Readiness Default | Description |
|-----------|------|------------------|-------------------|-------------|
| `probes.<type>.enabled` | bool | `true` | `true` | Enable probe |
| `probes.<type>.httpGet.path` | string | `/connectors` | `/connectors` | Endpoint path |
| `probes.<type>.httpGet.port` | string | `rest` | `rest` | Port name |
| `probes.<type>.initialDelaySeconds` | int | `60` | `30` | Startup grace period |
| `probes.<type>.periodSeconds` | int | `30` | `10` | Check interval |
| `probes.<type>.timeoutSeconds` | int | `10` | `5` | Timeout per check |
| `probes.<type>.failureThreshold` | int | `3` | `3` | Failures before action |

### Service

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `service.type` | string | `ClusterIP` | Service type |
| `service.port` | int | `8083` | Service port |
| `service.annotations` | map | `{}` | Service annotations |

### Environment Variables

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `env` | list | `[]` | Additional environment variables |
| `envFrom` | list | `[]` | Environment variable sources (configMapRef, secretRef) |

### Secrets

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `secrets.csi.enabled` | bool | `false` | Mount secrets via CSI driver |
| `secrets.csi.provider` | string | `""` | CSI provider name |
| `secrets.csi.aws.secretArn` | string | `""` | AWS Secrets Manager ARN |
| `secrets.csi.aws.keys` | list | `[]` | Key extraction entries |
| `secrets.kubernetes.enabled` | bool | `false` | Reference an existing K8s Secret |
| `secrets.kubernetes.name` | string | `""` | Name of the existing Secret |

### Service Account

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `serviceAccount.create` | bool | `true` | Create a ServiceAccount |
| `serviceAccount.name` | string | `""` | Override ServiceAccount name |
| `serviceAccount.annotations` | map | `{}` | ServiceAccount annotations (e.g., IRSA, GCP WI) |

### Scheduling

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `scheduling.nodeSelector` | map | `{}` | Node selector labels |
| `scheduling.tolerations` | list | `[]` | Tolerations |
| `scheduling.podAntiAffinity.enabled` | bool | `true` | Spread pods across zones |
| `scheduling.podAntiAffinity.type` | string | `preferred` | `preferred` or `required` |
| `scheduling.podAntiAffinity.topologyKey` | string | `topology.kubernetes.io/zone` | Topology key |

### Security Context

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `podSecurityContext.runAsNonRoot` | bool | `true` | Require non-root user |
| `podSecurityContext.seccompProfile.type` | string | `RuntimeDefault` | Seccomp profile |
| `securityContext.allowPrivilegeEscalation` | bool | `false` | Block privilege escalation |
| `securityContext.capabilities.drop` | list | `["ALL"]` | Dropped Linux capabilities |

### Istio

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `istio.enabled` | bool | `false` | Create Istio VirtualService |
| `istio.virtualService.hosts` | list | `[]` | VirtualService hostnames |
| `istio.virtualService.gateways` | list | `[]` | Gateway references |

### Monitoring

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `serviceMonitor.enabled` | bool | `false` | Create Prometheus ServiceMonitor |
| `serviceMonitor.interval` | string | `30s` | Scrape interval |
| `networkPolicy.enabled` | bool | `false` | Create a NetworkPolicy |

## How-To Guides

### Install Debezium and deploy a MongoDB CDC connector

```yaml
plugins:
  enabled: true
  confluentHub:
    - name: debezium-connector-mongodb
      owner: debezium
      version: "2.5.4"

connectorDeployJob:
  enabled: true

connectors:
  - name: mongodb-cdc
    config:
      connector.class: io.debezium.connector.mongodb.MongoDbConnector
      tasks.max: "1"
      mongodb.connection.string: "${env:MONGODB_URI}"
      topic.prefix: "cdc"
      capture.mode: change_streams_update_full
```

### Install multiple plugins for a CDC-to-S3 pipeline

```yaml
plugins:
  enabled: true
  confluentHub:
    - name: debezium-connector-postgresql
      owner: debezium
      version: "2.5.4"
    - name: kafka-connect-s3
      owner: confluentinc
      version: "10.5.13"
```

### Use a custom Docker image with pre-installed plugins

If you prefer baking plugins into the image (recommended for production):

```dockerfile
FROM confluentinc/cp-kafka-connect:7.7.0
RUN confluent-hub install --no-prompt debezium/debezium-connector-mongodb:2.5.4
RUN confluent-hub install --no-prompt confluentinc/kafka-connect-s3:10.5.13
```

Then reference it:

```yaml
image:
  repository: my-registry/custom-kafka-connect
  tag: "7.7.0-custom"
plugins:
  enabled: false  # plugins already in image
```

### Enable SASL_SSL authentication

```yaml
kafka:
  securityProtocol: SASL_SSL
  sasl:
    mechanism: SCRAM-SHA-512
    credentialsSecret:
      name: kafka-credentials
      usernameKey: username
      passwordKey: password
```

### Enable full observability (OTEL + JMX + monitor)

```yaml
otelAgent:
  enabled: true
  endpoint: "http://otel-collector.monitoring:4317"
jmxExporter:
  enabled: true
connectorMonitor:
  enabled: true
  autoRestart: true
serviceMonitor:
  enabled: true
```

### Inject secrets into connector configs via EnvVarConfigProvider

Kafka Connect's `${env:VAR_NAME}` syntax resolves environment variables at runtime:

```yaml
env:
  - name: MONGODB_URI
    valueFrom:
      secretKeyRef:
        name: mongodb-credentials
        key: connection-string
  - name: SNOWFLAKE_PRIVATE_KEY
    valueFrom:
      secretKeyRef:
        name: snowflake-credentials
        key: private-key

connectors:
  - name: my-source
    config:
      mongodb.connection.string: "${env:MONGODB_URI}"
  - name: my-sink
    config:
      snowflake.private.key: "${env:SNOWFLAKE_PRIVATE_KEY}"
```

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| Init container `install-plugins` fails | Plugin not found on Confluent Hub or network issue | Verify plugin `owner/name:version` at hub.confluent.io; check proxy/firewall |
| Deploy Job stuck waiting | Connect workers not ready or Service not routing | Check `kubectl get pods` for worker status; verify `service.port` matches `connect.restPort` |
| Connector FAILED after deploy | Invalid config, unreachable source/sink, or missing plugin | `curl <svc>:8083/connectors/<name>/status`; check logs with `kubectl logs` |
| Workers fail with `GroupCoordinator not available` | Internal topics missing or replication factor > broker count | Reduce `configStorageReplicationFactor` or add Kafka brokers |
| OOMKilled pods | Heap exceeds container memory limit | Ensure `jvm.heapSize` + ~512Mi overhead < `resources.limits.memory` |
| JMX metrics not in Prometheus | Exporter disabled or ServiceMonitor missing | Enable both `jmxExporter.enabled` and `serviceMonitor.enabled` |
| Connector monitor restarts in a loop | Connector fails immediately after restart due to data/config error | Disable `autoRestart`, check connector logs, fix root cause |
| `${env:VAR}` not resolved | Missing env var in pod spec | Add the variable to `env[]` or `envFrom[]` |
| Plugin installed but connector class not found | Plugin path mismatch | Verify `connect.pluginPath` includes `/opt/plugins` (auto-added when `plugins.enabled`) |

## Resources Created

| Condition | Resource | API Version |
|-----------|----------|-------------|
| Always | Deployment | `apps/v1` |
| Always | Service | `v1` |
| `serviceAccount.create` | ServiceAccount | `v1` |
| `podDisruptionBudget.enabled` | PodDisruptionBudget | `policy/v1` |
| `autoscaling.enabled` | HorizontalPodAutoscaler | `autoscaling/v2` |
| `jmxExporter.enabled` | ConfigMap (JMX rules) | `v1` |
| `connectorDeployJob.enabled` + `connectors` | Job (Helm post-install/upgrade hook) | `batch/v1` |
| `istio.enabled` | VirtualService | `networking.istio.io/v1beta1` |
| `serviceMonitor.enabled` | ServiceMonitor | `monitoring.coreos.com/v1` |
| `networkPolicy.enabled` | NetworkPolicy | `networking.k8s.io/v1` |
