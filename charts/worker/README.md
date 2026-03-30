# Worker Chart

Production-ready Helm chart for deploying batch Jobs and scheduled CronJobs on Kubernetes. Supports one-off tasks like database migrations, parallel batch processing with indexed completions, and recurring schedules with timezone-aware cron expressions, concurrency control, and automatic cleanup.

## Architecture

```
                    ┌──────────────────────────────┐
                    │      Kubernetes Cluster       │
                    │                              │
                    │  ┌────────────────────────┐  │
                    │  │  Job  (type: job)       │  │
                    │  │  ┌──────────────────┐  │  │
                    │  │  │ Pod              │  │  │
                    │  │  │  ┌────────────┐  │  │  │
                    │  │  │  │ init       │  │  │  │
                    │  │  │  │ container  │  │  │  │
                    │  │  │  └────────────┘  │  │  │
                    │  │  │  ┌────────────┐  │  │  │
                    │  │  │  │ worker     │  │  │  │
                    │  │  │  │ container  │  │  │  │
                    │  │  │  └────────────┘  │  │  │
                    │  │  │  CSI Volume      │  │  │
                    │  │  └──────────────────┘  │  │
                    │  │  ... x parallelism     │  │
                    │  └────────────────────────┘  │
                    │                              │
                    │  ┌────────────────────────┐  │
                    │  │  CronJob (type: cron)   │  │
                    │  │  schedule: "0 * * * *"  │  │
                    │  │  ┌──────────────────┐  │  │
                    │  │  │ Job (per trigger) │  │  │
                    │  │  └──────────────────┘  │  │
                    │  └────────────────────────┘  │
                    │                              │
                    │  ┌──────┐ ┌──────────────┐  │
                    │  │  SA  │ │ NetworkPolicy│  │
                    │  └──────┘ └──────────────┘  │
                    └──────────────────────────────┘
```

## Features

| Feature | Description | Enabled by |
|---------|-------------|-----------|
| Job | One-off batch execution with retries and deadlines | `type: job` |
| CronJob | Recurring scheduled execution with cron expressions | `type: cronjob` |
| Parallelism | Run multiple pods concurrently for batch processing | `job.parallelism` |
| Indexed Completions | Assign each pod a unique index for partitioned work | `job.completionMode: Indexed` |
| TTL Cleanup | Automatic pod cleanup after completion | `job.ttlSecondsAfterFinished` |
| Concurrency Policy | Prevent overlapping CronJob runs | `cronjob.concurrencyPolicy` |
| Timezone Support | IANA timezone for cron schedules | `cronjob.timeZone` |
| CSI Secrets | AWS Secrets Manager, Azure Key Vault, GCP, Vault | `secrets.csi.enabled` |
| K8s Secrets | Mount existing Secret as volume | `secrets.kubernetes.enabled` |
| ConfigMap | Chart-managed ConfigMap injected as env | `configMap.enabled` |
| ServiceAccount | Workload identity (IRSA, GCP WI, Azure WI) | `serviceAccount.create` |
| NetworkPolicy | Egress firewall rules | `networkPolicy.enabled` |
| Init Containers | Pre-task setup (fetch data, wait for deps) | `initContainers` |

## Prerequisites

- Kubernetes 1.26+
- Helm 3.12+

### Optional dependencies

| Feature | Requires |
|---------|----------|
| Timezone-aware CronJobs | Kubernetes 1.27+ with `CronJobTimeZone` feature gate |
| CSI secrets | [Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/) + cloud provider plugin |
| NetworkPolicy | CNI with NetworkPolicy support (Calico, Cilium, Antrea) |

## Quick Start

```bash
# One-off job
helm install db-migrate ./charts/worker \
  --set app.name=db-migrate \
  --set image.repository=my-registry/migrator \
  --set image.tag=1.0.0

# With a values file
helm install cleanup ./charts/worker -f my-values.yaml

# Dry run to inspect output
helm template cleanup ./charts/worker -f my-values.yaml
```

## Examples

| File | Use Case | Features Demonstrated |
|------|----------|----------------------|
| [db-migration.yaml](examples/db-migration.yaml) | Database migration job | One-off Job, backoff limit, TTL cleanup |
| [scheduled-cleanup.yaml](examples/scheduled-cleanup.yaml) | Scheduled CronJob | Cron schedule, concurrency policy, history limits |
| [batch-processing.yaml](examples/batch-processing.yaml) | Parallel batch job | Parallelism, indexed completions, resource limits |
| [etl-pipeline.yaml](examples/etl-pipeline.yaml) | ETL pipeline with init containers | Init containers, secrets, env configuration |

## Configuration Reference

### Application

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `app.name` | string | `my-worker` | Application name used in resource names |
| `fullnameOverride` | string | `""` | Override the full release name |
| `image.repository` | string | `busybox` | Container image repository |
| `image.tag` | string | `1.36` | Container image tag |
| `image.pullPolicy` | string | `IfNotPresent` | Image pull policy |
| `image.pullSecrets` | list | `[]` | Image pull secrets |
| `command` | list | `[]` | Override container command |
| `args` | list | `[]` | Override container args |

### Job Type

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `type` | string | `job` | Workload type: `job` or `cronjob` |

### Job Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `job.backoffLimit` | int | `3` | Max retries before marking as failed |
| `job.activeDeadlineSeconds` | int | `600` | Max total runtime in seconds |
| `job.ttlSecondsAfterFinished` | int | `3600` | Auto-cleanup delay after completion |
| `job.completions` | int | `1` | Number of successful completions required |
| `job.parallelism` | int | `1` | Number of pods running concurrently |
| `job.completionMode` | string | `NonIndexed` | `NonIndexed` or `Indexed` |
| `job.restartPolicy` | string | `OnFailure` | Pod restart policy |

### CronJob Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `cronjob.schedule` | string | `0 * * * *` | Cron expression |
| `cronjob.concurrencyPolicy` | string | `Forbid` | `Allow`, `Forbid`, or `Replace` |
| `cronjob.successfulJobsHistoryLimit` | int | `3` | Completed jobs to retain |
| `cronjob.failedJobsHistoryLimit` | int | `1` | Failed jobs to retain |
| `cronjob.startingDeadlineSeconds` | int | `300` | Max seconds past schedule to still start |
| `cronjob.suspend` | bool | `false` | Suspend future executions |
| `cronjob.timeZone` | string | `""` | IANA timezone (e.g., `America/New_York`) |

### Resources

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `resources.limits.cpu` | string | `500m` | CPU limit |
| `resources.limits.memory` | string | `512Mi` | Memory limit |
| `resources.requests.cpu` | string | `100m` | CPU request |
| `resources.requests.memory` | string | `128Mi` | Memory request |

### Environment and Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `env` | list | `[]` | Environment variables (`name`/`value` or `valueFrom`) |
| `envFrom` | list | `[]` | Env from Secret/ConfigMap references |
| `configMap.enabled` | bool | `false` | Create ConfigMap from `data` |
| `configMap.data` | map | `{}` | Key-value pairs injected as env vars |

### Secrets Management

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `secrets.csi.enabled` | bool | `false` | Enable Secrets Store CSI Driver |
| `secrets.csi.provider` | string | `""` | Provider: `aws`, `azure`, `gcp`, `vault` |
| `secrets.csi.aws.secretArn` | string | `""` | AWS Secrets Manager ARN |
| `secrets.csi.aws.keys` | list | `[]` | Keys to extract |
| `secrets.csi.azure.keyvaultName` | string | `""` | Azure Key Vault name |
| `secrets.csi.azure.tenantId` | string | `""` | Azure tenant ID |
| `secrets.csi.azure.objects` | list | `[]` | Azure Key Vault objects |
| `secrets.csi.gcp.projectId` | string | `""` | GCP project ID |
| `secrets.csi.gcp.secrets` | list | `[]` | GCP secret references |
| `secrets.csi.vault.roleName` | string | `""` | Vault auth role |
| `secrets.csi.vault.secretPath` | string | `""` | Vault secret path |
| `secrets.csi.vault.keys` | list | `[]` | Vault keys to extract |
| `secrets.csi.syncAsKubernetesSecret.enabled` | bool | `false` | Sync CSI secrets to K8s Secret |
| `secrets.csi.syncAsKubernetesSecret.secretName` | string | `""` | Target K8s Secret name |
| `secrets.csi.syncAsKubernetesSecret.type` | string | `Opaque` | K8s Secret type |
| `secrets.csi.syncAsKubernetesSecret.data` | list | `[]` | Secret data mappings |
| `secrets.kubernetes.enabled` | bool | `false` | Mount existing K8s Secret as volume |
| `secrets.kubernetes.name` | string | `""` | Secret name to mount |
| `secrets.kubernetes.mountPath` | string | `/mnt/secrets` | Mount path |
| `secrets.kubernetes.readOnly` | bool | `true` | Mount as read-only |

### Service Account

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `serviceAccount.create` | bool | `true` | Create ServiceAccount |
| `serviceAccount.name` | string | `""` | Override SA name (defaults to fullname) |
| `serviceAccount.annotations` | map | `{}` | SA annotations for cloud identity |
| `serviceAccount.automountServiceAccountToken` | bool | `false` | Mount API token into pods |

### Scheduling

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `scheduling.nodeSelector` | map | `{}` | Node selector labels |
| `scheduling.tolerations` | list | `[]` | Toleration rules |
| `scheduling.affinity` | map | `{}` | Custom affinity rules |

### Extensibility

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `initContainers` | list | `[]` | Init containers (full container spec) |
| `extraVolumes` | list | `[]` | Additional volumes |
| `extraVolumeMounts` | list | `[]` | Additional volume mounts on main container |
| `podAnnotations` | map | `{}` | Pod-level annotations |
| `podLabels` | map | `{}` | Additional pod labels |

### Security

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `podSecurityContext.runAsNonRoot` | bool | `true` | Require non-root user |
| `podSecurityContext.seccompProfile.type` | string | `RuntimeDefault` | Seccomp profile |
| `securityContext.allowPrivilegeEscalation` | bool | `false` | Block privilege escalation |
| `securityContext.readOnlyRootFilesystem` | bool | `true` | Read-only root FS |
| `securityContext.capabilities.drop` | list | `[ALL]` | Drop all Linux capabilities |

### Network Policy

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `networkPolicy.enabled` | bool | `false` | Create NetworkPolicy |
| `networkPolicy.egress` | list | `[]` | Egress rules (`to`, `ports`) |

## How-To Guides

### Run a database migration as a one-off Job

```yaml
type: job
app:
  name: db-migrate
image:
  repository: my-registry/migrator
  tag: "2.1.0"
command: ["migrate"]
args: ["-source", "file:///migrations", "-database", "$(DATABASE_URL)", "up"]
job:
  backoffLimit: 1
  activeDeadlineSeconds: 300
  ttlSecondsAfterFinished: 600
env:
  - name: DATABASE_URL
    valueFrom:
      secretKeyRef:
        name: db-credentials
        key: url
```

### Schedule a nightly cleanup CronJob

```yaml
type: cronjob
app:
  name: data-cleanup
image:
  repository: my-registry/cleaner
  tag: "1.0.0"
cronjob:
  schedule: "0 2 * * *"
  timeZone: "America/New_York"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 5
  failedJobsHistoryLimit: 3
```

### Run a parallel batch processing job

```yaml
type: job
app:
  name: batch-processor
image:
  repository: my-registry/processor
  tag: "3.0.0"
job:
  completions: 10
  parallelism: 5
  completionMode: Indexed
  activeDeadlineSeconds: 1800
resources:
  limits:
    cpu: "1"
    memory: 1Gi
```

### Fetch data before processing with init containers

```yaml
initContainers:
  - name: fetch-data
    image: curlimages/curl:8.5.0
    command:
      - sh
      - -c
      - curl -o /shared/data.json https://api.example.com/export
    volumeMounts:
      - name: shared
        mountPath: /shared
extraVolumes:
  - name: shared
    emptyDir: {}
extraVolumeMounts:
  - name: shared
    mountPath: /shared
```

### Temporarily suspend a CronJob

```yaml
cronjob:
  suspend: true
```

Or via CLI: `helm upgrade my-cron ./charts/worker --set cronjob.suspend=true`

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Job stuck in `Active` | `activeDeadlineSeconds` too high or container hanging | Lower `job.activeDeadlineSeconds` or fix container logic |
| CronJob never triggers | Schedule syntax wrong or `suspend: true` | Validate cron expression and check `cronjob.suspend` |
| Pods accumulating after completion | TTL controller not enabled | Set `job.ttlSecondsAfterFinished` or ensure TTL controller is enabled in cluster |
| CronJob runs overlap | `concurrencyPolicy` set to `Allow` | Switch `cronjob.concurrencyPolicy` to `Forbid` or `Replace` |
| Job exceeds backoff limit | Transient errors exhausting retries | Increase `job.backoffLimit` or fix the underlying error |
| `readOnlyRootFilesystem` errors | Worker writes temp files | Add emptyDir volume for writable paths |
| CronJob missed schedule | Cluster clock drift or too-short deadline | Increase `cronjob.startingDeadlineSeconds` |

## Resources Created

| Condition | Resource | API Version |
|-----------|----------|-------------|
| `type: job` | Job | `batch/v1` |
| `type: cronjob` | CronJob | `batch/v1` |
| `serviceAccount.create` | ServiceAccount | `v1` |
| `configMap.enabled` | ConfigMap | `v1` |
| `secrets.csi.enabled` | SecretProviderClass | `secrets-store.csi.x-k8s.io/v1` |
| `networkPolicy.enabled` | NetworkPolicy | `networking.k8s.io/v1` |
