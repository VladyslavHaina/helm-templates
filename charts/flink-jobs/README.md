# Flink Jobs

Helm chart for deploying Apache Flink workloads on Kubernetes using the Flink Kubernetes Operator. Supports both session mode (shared JobManager serving multiple FlinkSessionJobs) and application mode (dedicated cluster per job), with built-in checkpointing to S3/GCS/HDFS, savepoint management, configurable upgrade strategies, Log4j logging, and optional Ingress or Istio routing for the Flink Web UI.

## Architecture

```
                          +---------------------+
                          |   Flink Operator    |
                          |  (pre-installed)    |
                          +----------+----------+
                                     |  watches
                                     v
+------------------+      +---------------------+
|  Helm Release    | ---> | FlinkDeployment CR  |
|  (this chart)    |      +----------+----------+
+------------------+                 |
        |                            | creates
        |            +---------------+---------------+
        |            |                               |
        |            v                               v
        |   +-----------------+           +-------------------+
        |   |  Job Manager    |           |  Task Managers    |
        |   |  (replicas: N)  |           |  (replicas: M)    |
        |   +--------+--------+           +-------------------+
        |            |
        |            v
        |   +-----------------+
        +-->| FlinkSessionJob |  (session mode only)
            |  CRs (1..N)    |
            +-----------------+
                     |
          +----------+----------+
          |                     |
          v                     v
  +---------------+    +----------------+
  | S3/GCS/HDFS   |    | Ingress / Istio|
  | (checkpoints) |    | (Web UI)       |
  +---------------+    +----------------+
```

## Features

| Feature | Description | Enabled by |
|---------|-------------|------------|
| Session mode | Shared JobManager with multiple FlinkSessionJobs | `mode: session` |
| Application mode | Dedicated cluster per job | `mode: application` |
| Checkpointing | Periodic state snapshots to S3/GCS/HDFS | `flinkConfiguration.state.checkpoints.dir` |
| Savepoint management | Trigger savepoints via nonce field | `sessionJobs[].savepointTriggerNonce` |
| Upgrade modes | Stateless, savepoint, or last-state upgrades | `applicationJob.upgradeMode` / `sessionJobs[].upgradeMode` |
| Log4j logging | Configurable console pattern and per-package levels | `logging.*` |
| Ingress | Expose Flink Web UI via Kubernetes Ingress | `ingress.enabled: true` |
| Istio VirtualService | Route traffic through Istio service mesh | `istio.enabled: true` |
| Service Account | Dedicated RBAC identity for Flink pods | `serviceAccount.create: true` |

## Prerequisites

| Requirement | Minimum Version | Notes |
|-------------|----------------|-------|
| Kubernetes | 1.24+ | CRD support required |
| Helm | 3.10+ | OCI registry support recommended |
| Flink Kubernetes Operator | 1.6+ | Must be installed before deploying this chart |

| Optional Dependency | Purpose |
|---------------------|---------|
| S3-compatible storage | Checkpoint and savepoint persistence |
| cert-manager | TLS certificates for Ingress |
| Istio | VirtualService-based routing |

## Quick Start

```bash
helm repo add flink-jobs ./charts/flink-jobs
helm install my-flink ./charts/flink-jobs -n flink --create-namespace
helm status my-flink -n flink
```

## Examples

| File | Use Case | Features Demonstrated |
|------|----------|----------------------|
| [session-cluster.yaml](examples/session-cluster.yaml) | Session mode with 3 jobs | `mode: session`, `sessionJobs`, shared JobManager |
| [application-mode.yaml](examples/application-mode.yaml) | Single application job | `mode: application`, `applicationJob`, dedicated cluster |
| [with-checkpointing.yaml](examples/with-checkpointing.yaml) | S3 checkpointing and HA | `flinkConfiguration` checkpoint dirs, HA settings |
| [minimal.yaml](examples/minimal.yaml) | Minimal dev cluster | Lowest resource footprint for local development |

## Configuration Reference

### Cluster Metadata

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `cluster.name` | string | `my-flink` | Name used for the FlinkDeployment resource |
| `fullnameOverride` | string | `""` | Override the full resource name |

### Deployment Mode

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `mode` | string | `session` | Deployment mode: `session` or `application` |

### Image

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `image.repository` | string | `flink` | Flink container image repository |
| `image.tag` | string | `"1.19"` | Flink container image tag |
| `image.pullPolicy` | string | `IfNotPresent` | Image pull policy |

### Flink Version

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `flinkVersion` | string | `v1_19` | Flink version identifier for operator compatibility |

### Service Account

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `serviceAccount.create` | bool | `true` | Create a dedicated ServiceAccount |
| `serviceAccount.name` | string | `flink` | ServiceAccount name |
| `serviceAccount.annotations` | object | `{}` | Annotations on the ServiceAccount (e.g., IAM role) |

### Job Manager

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `jobManager.replicas` | int | `1` | JobManager replicas (increase for HA) |
| `jobManager.resources.limits.cpu` | string | `"1"` | CPU limit |
| `jobManager.resources.limits.memory` | string | `2Gi` | Memory limit |
| `jobManager.resources.requests.cpu` | string | `500m` | CPU request |
| `jobManager.resources.requests.memory` | string | `1Gi` | Memory request |
| `jobManager.podTemplate` | object | `{}` | Additional pod template overrides |

### Task Manager

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `taskManager.replicas` | int | `2` | Number of TaskManager pods |
| `taskManager.resources.limits.cpu` | string | `"2"` | CPU limit |
| `taskManager.resources.limits.memory` | string | `4Gi` | Memory limit |
| `taskManager.resources.requests.cpu` | string | `"1"` | CPU request |
| `taskManager.resources.requests.memory` | string | `2Gi` | Memory request |
| `taskManager.taskSlots` | int | `2` | Number of task slots per TaskManager |
| `taskManager.podTemplate` | object | `{}` | Additional pod template overrides |

### Flink Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `flinkConfiguration.taskmanager.numberOfTaskSlots` | string | `"2"` | Task slots per TaskManager (string) |
| `flinkConfiguration.state.backend` | string | `hashmap` | State backend type (`hashmap`, `rocksdb`) |
| `flinkConfiguration.state.checkpoints.dir` | string | `""` | Checkpoint directory (e.g., `s3://bucket/cp`) |
| `flinkConfiguration.state.savepoints.dir` | string | `""` | Savepoint directory (e.g., `s3://bucket/sp`) |
| `flinkConfiguration.execution.checkpointing.interval` | string | `"60000"` | Checkpoint interval in milliseconds |
| `flinkConfiguration.execution.checkpointing.min-pause` | string | `"30000"` | Minimum pause between checkpoints (ms) |
| `flinkConfiguration.execution.checkpointing.timeout` | string | `"600000"` | Checkpoint timeout in milliseconds |
| `flinkConfiguration.execution.checkpointing.externalized-checkpoint-retention` | string | `RETAIN_ON_CANCELLATION` | Retain checkpoints after cancellation |
| `flinkConfiguration.web.cancel.enable` | string | `"true"` | Allow job cancellation from Web UI |

### Session Jobs

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `sessionJobs` | list | `[]` | List of FlinkSessionJob definitions (session mode) |
| `sessionJobs[].name` | string | -- | Job name |
| `sessionJobs[].jarURI` | string | -- | JAR artifact URI (e.g., `s3://bucket/job.jar`) |
| `sessionJobs[].parallelism` | int | -- | Job parallelism |
| `sessionJobs[].entryClass` | string | -- | Main class fully qualified name |
| `sessionJobs[].args` | list | `[]` | Command-line arguments |
| `sessionJobs[].upgradeMode` | string | `last-state` | Upgrade mode: `stateless`, `savepoint`, `last-state` |
| `sessionJobs[].allowNonRestoredState` | bool | `false` | Allow starting without full state restore |
| `sessionJobs[].savepointTriggerNonce` | int | `0` | Increment to trigger a savepoint |

### Application Job

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `applicationJob.jarURI` | string | `""` | JAR artifact URI |
| `applicationJob.entryClass` | string | `""` | Main class fully qualified name |
| `applicationJob.parallelism` | int | `1` | Job parallelism |
| `applicationJob.args` | list | `[]` | Command-line arguments |
| `applicationJob.upgradeMode` | string | `last-state` | Upgrade mode: `stateless`, `savepoint`, `last-state` |
| `applicationJob.allowNonRestoredState` | bool | `false` | Allow starting without full state restore |

### Pod Template

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `podTemplate.annotations` | object | `{}` | Annotations applied to all Flink pods |
| `podTemplate.labels` | object | `{}` | Labels applied to all Flink pods |

### Ingress

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ingress.enabled` | bool | `false` | Enable Ingress for Flink Web UI |
| `ingress.className` | string | `""` | Ingress class name |
| `ingress.annotations` | object | `{}` | Ingress annotations |
| `ingress.host` | string | `""` | Hostname for the Ingress rule |
| `ingress.tls` | list | `[]` | TLS configuration blocks |

### Istio

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `istio.enabled` | bool | `false` | Create an Istio VirtualService |
| `istio.virtualService.hosts` | list | `[]` | VirtualService hostnames |
| `istio.virtualService.gateways` | list | `[]` | Istio Gateway references |

### Logging

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `logging.log4jConsolePattern` | string | `"%d{yyyy-MM-dd HH:mm:ss,SSS} %-5p %-60c %x - %m%n"` | Log4j console output pattern |
| `logging.rootLoggerLevel` | string | `INFO` | Root logger level |
| `logging.extraLoggers` | object | `{}` | Per-package log levels (e.g., `com.example: DEBUG`) |

### Environment

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `env` | list | `[]` | Extra environment variables for Flink containers |
| `envFrom` | list | `[]` | Extra envFrom sources (ConfigMaps, Secrets) |

### Volumes

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `extraVolumes` | list | `[]` | Additional volumes to attach to pods |
| `extraVolumeMounts` | list | `[]` | Additional volume mounts for containers |

## How-To Guides

### Enable S3 checkpointing

```yaml
flinkConfiguration:
  state.backend: rocksdb
  state.checkpoints.dir: s3://my-bucket/flink/checkpoints
  state.savepoints.dir: s3://my-bucket/flink/savepoints

serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789:role/flink-s3
```

### Add a session job

```yaml
mode: session
sessionJobs:
  - name: click-aggregator
    jarURI: "s3://my-bucket/jobs/click-agg-2.1.0.jar"
    parallelism: 4
    entryClass: com.example.ClickAggregator
    upgradeMode: last-state
```

### Trigger a savepoint

Increment the `savepointTriggerNonce` for the target job and run `helm upgrade`:

```yaml
sessionJobs:
  - name: click-aggregator
    savepointTriggerNonce: 1   # was 0, now 1
```

### Expose the Web UI with Ingress

```yaml
ingress:
  enabled: true
  className: nginx
  host: flink.example.com
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
  tls:
    - secretName: flink-tls
      hosts:
        - flink.example.com
```

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| FlinkDeployment stays in `RECONCILING` | Flink Operator not installed or wrong version | Install the Flink Kubernetes Operator >= 1.6 |
| TaskManagers crash with OOM | Memory limit too low for workload | Increase `taskManager.resources.limits.memory` |
| Checkpoint failures | Missing or unreachable storage path | Verify `state.checkpoints.dir` and IAM/RBAC permissions |
| Session job stuck in `SUSPENDED` | JAR URI not accessible from the cluster | Check `jarURI` path and network/storage access |
| Web UI not reachable via Ingress | Ingress class or host misconfigured | Verify `ingress.className` and DNS resolution |
| Savepoint not triggered | `savepointTriggerNonce` not incremented | Bump the nonce value and run `helm upgrade` |
| Pods in `Pending` state | Insufficient cluster resources | Check node capacity or scale the node pool |

## Resources Created

| Condition | Resource | API Version |
|-----------|----------|-------------|
| Always | FlinkDeployment | `flink.apache.org/v1beta1` |
| `mode: session` and `sessionJobs` defined | FlinkSessionJob (per job) | `flink.apache.org/v1beta1` |
| `serviceAccount.create: true` | ServiceAccount | `v1` |
| Always | ConfigMap (log4j) | `v1` |
| `ingress.enabled: true` | Ingress | `networking.k8s.io/v1` |
| `istio.enabled: true` | VirtualService | `networking.istio.io/v1beta1` |
