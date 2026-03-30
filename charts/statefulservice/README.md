# StatefulService Chart

Production-ready Helm chart for deploying stateful workloads (databases, caches, message queues) on Kubernetes using StatefulSet. Provides stable network identities, persistent storage with configurable retention policies, ordered pod management, and the same security, secrets, and observability primitives found in the microservice chart.

## Architecture

```
                    ┌──────────────────────────────┐
                    │      Kubernetes Cluster       │
                    │                              │
  ┌─────────┐      │  ┌────────────────────────┐  │
  │ Ingress │──────│──│  Headless Service       │  │
  │ or Istio│      │  │  (clusterIP: None)      │  │
  │ Gateway │      │  └────────┬───────────────┘  │
  └─────────┘      │           │                  │
                    │  ┌───────▼────────────────┐  │
                    │  │  StatefulSet            │  │
                    │  │  ┌──────────────────┐  │  │
                    │  │  │ Pod-0            │  │  │
                    │  │  │  ┌────────────┐  │  │  │
                    │  │  │  │ main       │  │  │  │
                    │  │  │  │ container  │  │  │  │
                    │  │  │  └────────────┘  │  │  │
                    │  │  │  ┌────────────┐  │  │  │
                    │  │  │  │ PVC: data  │  │  │  │
                    │  │  │  └────────────┘  │  │  │
                    │  │  └──────────────────┘  │  │
                    │  │  Pod-1, Pod-2, ...     │  │
                    │  └────────────────────────┘  │
                    │                              │
                    │  ┌─────┐ ┌─────┐ ┌────────┐ │
                    │  │ PDB │ │ SM  │ │Std Svc │ │
                    │  └─────┘ └─────┘ └────────┘ │
                    └──────────────────────────────┘
```

## Features

| Feature | Description | Enabled by |
|---------|-------------|-----------|
| StatefulSet | Ordered/Parallel pod management, stable network IDs | Always |
| Headless Service | Stable DNS per pod (pod-0.svc, pod-1.svc) | `service.headless.enabled` |
| Standard Service | Optional ClusterIP service for client access | `service.standard.enabled` |
| PVC Templates | Persistent storage with retention policies | `volumeClaimTemplates` |
| PDB | Availability guarantee during disruptions | `podDisruptionBudget.enabled` |
| Health Probes | Liveness, readiness, startup (TCP socket) | `probes.*.enabled` |
| Ingress | Standard Kubernetes Ingress with TLS | `ingress.enabled` |
| Istio VirtualService | Routing, retries, timeouts, traffic splitting | `istio.enabled` |
| Istio DestinationRule | Connection pooling, outlier detection | `istio.destinationRule.enabled` |
| CSI Secrets | AWS Secrets Manager, Azure Key Vault, GCP, Vault | `secrets.csi.enabled` |
| K8s Secrets | Mount existing Secret as volume | `secrets.kubernetes.enabled` |
| ConfigMap | Chart-managed ConfigMap injected as env | `configMap.enabled` |
| ServiceAccount | Workload identity (IRSA, GCP WI, Azure WI) | `serviceAccount.create` |
| ServiceMonitor | Prometheus operator scraping | `serviceMonitor.enabled` |
| NetworkPolicy | Ingress/egress firewall rules | `networkPolicy.enabled` |
| Init Containers | Pre-start setup (schema init, data restore) | `initContainers` |
| Sidecars | Log shippers, backup agents | `extraContainers` |

## Prerequisites

- Kubernetes 1.26+
- Helm 3.12+

### Optional dependencies

| Feature | Requires |
|---------|----------|
| PVC retention policy | Kubernetes 1.27+ with `StatefulSetAutoDeletePVC` feature gate |
| Istio routing | [Istio](https://istio.io/) service mesh installed |
| CSI secrets | [Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/) + cloud provider plugin |
| ServiceMonitor | [Prometheus Operator](https://prometheus-operator.dev/) (kube-prometheus-stack) |
| NetworkPolicy | CNI with NetworkPolicy support (Calico, Cilium, Antrea) |
| Ingress | Ingress controller (nginx, Traefik, AWS ALB, GCE) |

## Quick Start

```bash
# Minimal deployment
helm install my-db ./charts/statefulservice \
  --set app.name=my-db \
  --set image.repository=postgres \
  --set image.tag=16-alpine

# With a values file
helm install my-db ./charts/statefulservice -f my-values.yaml

# Dry run to inspect output
helm template my-db ./charts/statefulservice -f my-values.yaml
```

## Examples

| File | Use Case | Features Demonstrated |
|------|----------|----------------------|
| [postgresql.yaml](examples/postgresql.yaml) | PostgreSQL with persistent storage | PVC templates, TCP probes, headless service |
| [redis-cluster.yaml](examples/redis-cluster.yaml) | Redis 3-node cluster | Parallel pod management, anti-affinity |
| [elasticsearch.yaml](examples/elasticsearch.yaml) | Elasticsearch data node | Large PVC, custom resources, init containers |
| [minimal.yaml](examples/minimal.yaml) | Minimal single-replica for dev | Smallest footprint for local development |

## Configuration Reference

### Application

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `app.name` | string | `my-stateful-service` | Application name used in resource names |
| `fullnameOverride` | string | `""` | Override the full release name |
| `image.repository` | string | `postgres` | Container image repository |
| `image.tag` | string | `16-alpine` | Container image tag |
| `image.pullPolicy` | string | `IfNotPresent` | Image pull policy |
| `image.pullSecrets` | list | `[]` | Image pull secrets |
| `command` | list | `[]` | Override container command |
| `args` | list | `[]` | Override container args |

### StatefulSet

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `replicaCount` | int | `3` | Number of replicas |
| `podManagementPolicy` | string | `OrderedReady` | `OrderedReady` or `Parallel` |
| `updateStrategy.type` | string | `RollingUpdate` | `RollingUpdate` or `OnDelete` |
| `persistentVolumeClaimRetentionPolicy.whenDeleted` | string | `Retain` | PVC policy when StatefulSet deleted |
| `persistentVolumeClaimRetentionPolicy.whenScaled` | string | `Retain` | PVC policy when scaled down |

### Volume Claim Templates

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `volumeClaimTemplates[].name` | string | `data` | PVC name |
| `volumeClaimTemplates[].accessModes` | list | `[ReadWriteOnce]` | PVC access modes |
| `volumeClaimTemplates[].storageClassName` | string | `""` | Storage class (empty uses cluster default) |
| `volumeClaimTemplates[].size` | string | `50Gi` | Storage size |

### Resources

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `resources.limits.cpu` | string | `2` | CPU limit |
| `resources.limits.memory` | string | `4Gi` | Memory limit |
| `resources.requests.cpu` | string | `500m` | CPU request |
| `resources.requests.memory` | string | `2Gi` | Memory request |

### Services

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `service.headless.enabled` | bool | `true` | Create headless Service (clusterIP: None) |
| `service.headless.port` | int | `5432` | Headless service port |
| `service.headless.targetPort` | int | `5432` | Container port |
| `service.headless.protocol` | string | `TCP` | Port protocol |
| `service.headless.annotations` | map | `{}` | Headless service annotations |
| `service.standard.enabled` | bool | `false` | Create standard ClusterIP Service |
| `service.standard.type` | string | `ClusterIP` | Standard service type |
| `service.standard.port` | int | `5432` | Standard service port |
| `service.standard.targetPort` | int | `5432` | Container port |
| `service.standard.annotations` | map | `{}` | Standard service annotations |

### Pod Disruption Budget

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `podDisruptionBudget.enabled` | bool | `false` | Enable PDB |
| `podDisruptionBudget.minAvailable` | int | `1` | Minimum available pods |

### Health Probes

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `probes.liveness.enabled` | bool | `true` | Enable liveness probe |
| `probes.liveness.tcpSocket.port` | int | `5432` | TCP port to check |
| `probes.liveness.initialDelaySeconds` | int | `30` | Delay before first check |
| `probes.liveness.periodSeconds` | int | `10` | Check interval |
| `probes.liveness.timeoutSeconds` | int | `5` | Probe timeout |
| `probes.liveness.failureThreshold` | int | `3` | Failures before restart |
| `probes.readiness.enabled` | bool | `true` | Enable readiness probe |
| `probes.readiness.tcpSocket.port` | int | `5432` | TCP port to check |
| `probes.readiness.initialDelaySeconds` | int | `10` | Delay before first check |
| `probes.readiness.periodSeconds` | int | `5` | Check interval |
| `probes.readiness.timeoutSeconds` | int | `3` | Probe timeout |
| `probes.readiness.failureThreshold` | int | `3` | Failures before marking unready |
| `probes.startup.enabled` | bool | `false` | Enable startup probe |
| `probes.startup.tcpSocket.port` | int | `5432` | TCP port to check |
| `probes.startup.initialDelaySeconds` | int | `0` | Delay before first check |
| `probes.startup.periodSeconds` | int | `5` | Check interval |
| `probes.startup.failureThreshold` | int | `30` | Failures before kill |

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
| `scheduling.topologySpreadConstraints` | list | `[]` | Topology spread constraints |
| `scheduling.podAntiAffinity.enabled` | bool | `true` | Spread pods across failure domains |
| `scheduling.podAntiAffinity.type` | string | `preferred` | `preferred` (soft) or `required` (hard) |
| `scheduling.podAntiAffinity.topologyKey` | string | `topology.kubernetes.io/zone` | Failure domain key |

### Ingress

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ingress.enabled` | bool | `false` | Enable Kubernetes Ingress |
| `ingress.className` | string | `""` | Ingress class |
| `ingress.annotations` | map | `{}` | Ingress annotations |
| `ingress.hosts` | list | `[]` | Host and path routing rules |
| `ingress.tls` | list | `[]` | TLS secrets for HTTPS termination |

### Istio

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `istio.enabled` | bool | `false` | Enable Istio VirtualService |
| `istio.virtualService.hosts` | list | `[]` | VirtualService hostnames |
| `istio.virtualService.gateways` | list | `[]` | Gateway references |
| `istio.virtualService.http` | list | `[]` | HTTP routing rules |
| `istio.destinationRule.enabled` | bool | `false` | Enable DestinationRule |
| `istio.destinationRule.trafficPolicy` | map | `{}` | Connection pooling, load balancer, outlier detection |

### Extensibility

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `initContainers` | list | `[]` | Init containers (full container spec) |
| `extraContainers` | list | `[]` | Sidecar containers (full container spec) |
| `extraVolumes` | list | `[]` | Additional volumes (beyond PVC templates) |
| `extraVolumeMounts` | list | `[]` | Additional volume mounts on main container |
| `podAnnotations` | map | `{}` | Pod-level annotations |
| `podLabels` | map | `{}` | Additional pod labels |

### Security

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `podSecurityContext.runAsNonRoot` | bool | `true` | Require non-root user |
| `podSecurityContext.seccompProfile.type` | string | `RuntimeDefault` | Seccomp profile |
| `securityContext.allowPrivilegeEscalation` | bool | `false` | Block privilege escalation |
| `securityContext.readOnlyRootFilesystem` | bool | `false` | Read-only root FS (disabled for databases) |
| `securityContext.capabilities.drop` | list | `[ALL]` | Drop all Linux capabilities |

### Observability

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `serviceMonitor.enabled` | bool | `false` | Create Prometheus ServiceMonitor |
| `serviceMonitor.interval` | string | `30s` | Scrape interval |
| `serviceMonitor.path` | string | `/metrics` | Metrics endpoint path |
| `serviceMonitor.port` | string | `metrics` | Port to scrape |

### Network Policy

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `networkPolicy.enabled` | bool | `false` | Create NetworkPolicy |
| `networkPolicy.ingress` | list | `[]` | Ingress rules (`from`, `ports`) |
| `networkPolicy.egress` | list | `[]` | Egress rules (`to`, `ports`) |

## How-To Guides

### Deploy a PostgreSQL instance with persistent storage

```yaml
app:
  name: my-postgres
image:
  repository: postgres
  tag: "16-alpine"
replicaCount: 1
volumeClaimTemplates:
  - name: data
    size: 100Gi
    storageClassName: gp3
env:
  - name: POSTGRES_DB
    value: mydb
  - name: POSTGRES_PASSWORD
    valueFrom:
      secretKeyRef:
        name: pg-secret
        key: password
```

### Run a Redis cluster with parallel pod management

```yaml
app:
  name: redis-cluster
image:
  repository: redis
  tag: "7-alpine"
replicaCount: 3
podManagementPolicy: Parallel
service:
  headless:
    port: 6379
    targetPort: 6379
probes:
  liveness:
    tcpSocket:
      port: 6379
  readiness:
    tcpSocket:
      port: 6379
```

### Configure PVC retention for safe scale-down

```yaml
persistentVolumeClaimRetentionPolicy:
  whenDeleted: Delete
  whenScaled: Retain
volumeClaimTemplates:
  - name: data
    size: 50Gi
    storageClassName: standard
```

### Add a backup sidecar

```yaml
extraContainers:
  - name: backup-agent
    image: my-registry/backup-agent:1.0
    volumeMounts:
      - name: data
        mountPath: /data
        readOnly: true
    resources:
      limits:
        cpu: 200m
        memory: 256Mi
```

### Wait for a dependency before starting

```yaml
initContainers:
  - name: wait-for-consul
    image: busybox:1.36
    command:
      - sh
      - -c
      - |
        until nc -z consul.default.svc.cluster.local 8500; do
          echo "Waiting for Consul..."
          sleep 2
        done
```

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Pod stuck in `Pending` | PVC cannot be provisioned | Check `storageClassName` exists and has available capacity |
| Pods start out of order | `podManagementPolicy` set to `OrderedReady` and previous pod unhealthy | Fix readiness probe on earlier pods or switch to `Parallel` |
| PVC not deleted on scale-down | Retention policy set to `Retain` | Set `persistentVolumeClaimRetentionPolicy.whenScaled: Delete` (K8s 1.27+) |
| DNS resolution fails between pods | Headless service disabled or misconfigured | Ensure `service.headless.enabled: true` and port matches container |
| Pod in `CrashLoopBackOff` | Probe fires before database ready | Enable `probes.startup` with high `failureThreshold` to allow slow starts |
| Anti-affinity prevents scheduling | Not enough nodes across zones | Switch `scheduling.podAntiAffinity.type` from `required` to `preferred` |
| Data loss after StatefulSet delete | Retention policy was `Delete` | Use `persistentVolumeClaimRetentionPolicy.whenDeleted: Retain` (default) |

## Resources Created

| Condition | Resource | API Version |
|-----------|----------|-------------|
| Always | StatefulSet | `apps/v1` |
| `service.headless.enabled` | Service (headless) | `v1` |
| `service.standard.enabled` | Service (ClusterIP) | `v1` |
| `serviceAccount.create` | ServiceAccount | `v1` |
| `podDisruptionBudget.enabled` | PodDisruptionBudget | `policy/v1` |
| `configMap.enabled` | ConfigMap | `v1` |
| `ingress.enabled` | Ingress | `networking.k8s.io/v1` |
| `istio.enabled` | VirtualService | `networking.istio.io/v1beta1` |
| `istio.destinationRule.enabled` | DestinationRule | `networking.istio.io/v1beta1` |
| `secrets.csi.enabled` | SecretProviderClass | `secrets-store.csi.x-k8s.io/v1` |
| `serviceMonitor.enabled` | ServiceMonitor | `monitoring.coreos.com/v1` |
| `networkPolicy.enabled` | NetworkPolicy | `networking.k8s.io/v1` |
