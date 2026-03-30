# Microservice Chart

Production-ready Helm chart for deploying stateless microservices on Kubernetes. Covers the full lifecycle from basic deployments to production-grade setups with autoscaling, observability, secrets management, and zero-trust networking.

## Architecture

```
                    ┌──────────────────────────┐
                    │      Kubernetes Cluster   │
                    │                          │
  ┌─────────┐      │  ┌────────────────────┐  │
  │ Ingress │──────│──│  Service            │  │
  │ or Istio│      │  │  (ClusterIP)        │  │
  │ Gateway │      │  └────────┬───────────┘  │
  └─────────┘      │           │              │
                    │  ┌───────▼────────────┐  │
                    │  │  Deployment         │  │
                    │  │  ┌──────────────┐  │  │
                    │  │  │ Pod          │  │  │
                    │  │  │  ┌────────┐  │  │  │
                    │  │  │  │main    │  │  │  │
                    │  │  │  │container│  │  │  │
                    │  │  │  └────────┘  │  │  │
                    │  │  │  ┌────────┐  │  │  │
                    │  │  │  │sidecar │  │  │  │
                    │  │  │  │(opt)   │  │  │  │
                    │  │  │  └────────┘  │  │  │
                    │  │  │  CSI Volume  │  │  │
                    │  │  └──────────────┘  │  │
                    │  │  ... x replicas    │  │
                    │  └────────────────────┘  │
                    │                          │
                    │  ┌─────┐ ┌─────┐ ┌────┐ │
                    │  │ HPA │ │ PDB │ │ SM │ │
                    │  └─────┘ └─────┘ └────┘ │
                    └──────────────────────────┘
```

## Features

| Feature | Description | Enabled by |
|---------|-------------|-----------|
| Deployment | RollingUpdate/Recreate strategy, pod anti-affinity | Always |
| Service | ClusterIP/NodePort/LoadBalancer | `service.enabled` |
| HPA | CPU, memory, custom behavior policies (autoscaling/v2) | `autoscaling.enabled` |
| PDB | Availability guarantee during disruptions | `podDisruptionBudget.enabled` |
| Health Probes | Liveness, readiness, startup (HTTP/TCP) | `probes.*.enabled` |
| Ingress | Standard Kubernetes Ingress with TLS | `ingress.enabled` |
| Istio VirtualService | Routing, retries, timeouts, traffic splitting | `istio.enabled` |
| Istio DestinationRule | Connection pooling, outlier detection | `istio.destinationRule.enabled` |
| CSI Secrets | AWS Secrets Manager, Azure Key Vault, GCP, Vault | `secrets.csi.enabled` |
| K8s Secrets | Mount existing Secret as volume | `secrets.kubernetes.enabled` |
| ConfigMap | Chart-managed ConfigMap injected as env | `configMap.enabled` |
| ServiceAccount | Workload identity (IRSA, GCP WI, Azure WI) | `serviceAccount.create` |
| ServiceMonitor | Prometheus operator scraping | `serviceMonitor.enabled` |
| NetworkPolicy | Ingress/egress firewall rules | `networkPolicy.enabled` |
| Init Containers | Pre-start setup (DB wait, migrations) | `initContainers` |
| Sidecars | Log shippers, proxies, agents | `extraContainers` |

## Prerequisites

- Kubernetes 1.26+
- Helm 3.12+

### Optional dependencies

| Feature | Requires |
|---------|----------|
| Istio routing | [Istio](https://istio.io/) service mesh installed |
| CSI secrets | [Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/) + cloud provider plugin |
| ServiceMonitor | [Prometheus Operator](https://prometheus-operator.dev/) (kube-prometheus-stack) |
| NetworkPolicy | CNI with NetworkPolicy support (Calico, Cilium, Antrea) |
| Ingress | Ingress controller (nginx, Traefik, AWS ALB, GCE) |

## Quick Start

```bash
# Minimal deployment
helm install my-api ./charts/microservice \
  --set app.name=my-api \
  --set image.repository=my-registry/my-api \
  --set image.tag=1.0.0

# With a values file
helm install my-api ./charts/microservice -f my-values.yaml

# Dry run to inspect output
helm template my-api ./charts/microservice -f my-values.yaml
```

## Examples

| File | Use Case | Features Demonstrated |
|------|----------|----------------------|
| [basic.yaml](examples/basic.yaml) | Get started quickly | Deployment + Service + probes |
| [full-featured.yaml](examples/full-featured.yaml) | Production with everything on | HPA, PDB, Ingress, ServiceMonitor, NetworkPolicy, ConfigMap, env |
| [aws-irsa-istio.yaml](examples/aws-irsa-istio.yaml) | AWS EKS production | IRSA ServiceAccount, Secrets Manager CSI, Istio VirtualService + DestinationRule |
| [gcp-workload-identity.yaml](examples/gcp-workload-identity.yaml) | GCP GKE production | GCP Workload Identity, GCP Secret Manager CSI, GCE Ingress |
| [azure-workload-identity.yaml](examples/azure-workload-identity.yaml) | Azure AKS production | Azure Workload Identity, Key Vault CSI, App Gateway Ingress |
| [with-monitoring.yaml](examples/with-monitoring.yaml) | Observability setup | ServiceMonitor, all probes, Prometheus annotations |
| [with-init-containers.yaml](examples/with-init-containers.yaml) | Complex pod setup | Init containers (DB wait + migration), sidecar (Fluent Bit), shared volumes |

## Configuration Reference

### Application

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `app.name` | string | `my-service` | Application name used in resource names |
| `fullnameOverride` | string | `""` | Override the full release name |
| `image.repository` | string | `nginx` | Container image repository |
| `image.tag` | string | `1.27` | Container image tag |
| `image.pullPolicy` | string | `IfNotPresent` | Image pull policy |
| `image.pullSecrets` | list | `[]` | Image pull secrets |
| `command` | list | `[]` | Override container command |
| `args` | list | `[]` | Override container args |

### Deployment

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `replicaCount` | int | `2` | Number of replicas (ignored when HPA enabled) |
| `strategy.type` | string | `RollingUpdate` | `RollingUpdate` or `Recreate` |
| `strategy.rollingUpdate.maxSurge` | int | `1` | Max pods above desired during update |
| `strategy.rollingUpdate.maxUnavailable` | int | `0` | Max unavailable pods during update |

### Resources

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `resources.limits.cpu` | string | `500m` | CPU limit |
| `resources.limits.memory` | string | `512Mi` | Memory limit |
| `resources.requests.cpu` | string | `100m` | CPU request |
| `resources.requests.memory` | string | `128Mi` | Memory request |

### Service

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `service.enabled` | bool | `true` | Create a Service |
| `service.type` | string | `ClusterIP` | Service type |
| `service.port` | int | `80` | Service port |
| `service.targetPort` | int | `8080` | Container port |
| `service.protocol` | string | `TCP` | Port protocol |
| `service.annotations` | map | `{}` | Service annotations |

### Autoscaling (HPA)

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `autoscaling.enabled` | bool | `false` | Enable HPA |
| `autoscaling.minReplicas` | int | `2` | Minimum replicas |
| `autoscaling.maxReplicas` | int | `10` | Maximum replicas |
| `autoscaling.targetCPUUtilizationPercentage` | int | `75` | Target CPU % |
| `autoscaling.targetMemoryUtilizationPercentage` | int | `80` | Target memory % |
| `autoscaling.behavior` | map | `{}` | [Scaling behavior policies](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/#configurable-scaling-behavior) |

### Pod Disruption Budget

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `podDisruptionBudget.enabled` | bool | `false` | Enable PDB |
| `podDisruptionBudget.minAvailable` | int | `1` | Minimum available pods |
| `podDisruptionBudget.maxUnavailable` | int | - | Max unavailable pods (alternative to minAvailable) |

### Health Probes

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `probes.liveness.enabled` | bool | `true` | Enable liveness probe |
| `probes.liveness.httpGet.path` | string | `/healthz` | HTTP path |
| `probes.liveness.httpGet.port` | string | `http` | Port name or number |
| `probes.liveness.initialDelaySeconds` | int | `15` | Delay before first check |
| `probes.liveness.periodSeconds` | int | `10` | Check interval |
| `probes.liveness.timeoutSeconds` | int | `5` | Probe timeout |
| `probes.liveness.failureThreshold` | int | `3` | Failures before restart |
| `probes.readiness.enabled` | bool | `true` | Enable readiness probe |
| `probes.readiness.httpGet.path` | string | `/ready` | HTTP path |
| `probes.readiness.initialDelaySeconds` | int | `5` | Delay before first check |
| `probes.startup.enabled` | bool | `false` | Enable startup probe |
| `probes.startup.failureThreshold` | int | `30` | Failures before kill (startup x period = max startup time) |

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
| `secrets.csi.aws.keys` | list | `[]` | Keys to extract (`objectName`, `objectAlias`, `jmesPath`) |
| `secrets.csi.azure.keyvaultName` | string | `""` | Azure Key Vault name |
| `secrets.csi.azure.tenantId` | string | `""` | Azure tenant ID |
| `secrets.csi.gcp.projectId` | string | `""` | GCP project ID |
| `secrets.csi.gcp.secrets` | list | `[]` | GCP secret references (`resourceName`, `objectName`) |
| `secrets.csi.vault.roleName` | string | `""` | Vault auth role |
| `secrets.csi.vault.secretPath` | string | `""` | Vault secret path |
| `secrets.csi.syncAsKubernetesSecret.enabled` | bool | `false` | Sync CSI secrets to K8s Secret (puts in etcd) |
| `secrets.kubernetes.enabled` | bool | `false` | Mount existing K8s Secret as volume |
| `secrets.kubernetes.name` | string | `""` | Secret name to mount |
| `secrets.kubernetes.mountPath` | string | `/mnt/secrets` | Mount path |

### Service Account

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `serviceAccount.create` | bool | `true` | Create ServiceAccount |
| `serviceAccount.name` | string | `""` | Override SA name (defaults to fullname) |
| `serviceAccount.annotations` | map | `{}` | SA annotations for cloud identity (IRSA, GCP WI, Azure WI) |
| `serviceAccount.automountServiceAccountToken` | bool | `false` | Mount API token into pods |

### Scheduling

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `scheduling.nodeSelector` | map | `{}` | Node selector labels |
| `scheduling.tolerations` | list | `[]` | Toleration rules |
| `scheduling.affinity` | map | `{}` | Custom affinity rules (merged with podAntiAffinity) |
| `scheduling.topologySpreadConstraints` | list | `[]` | Topology spread constraints |
| `scheduling.podAntiAffinity.enabled` | bool | `true` | Spread pods across failure domains |
| `scheduling.podAntiAffinity.type` | string | `preferred` | `preferred` (soft) or `required` (hard) |
| `scheduling.podAntiAffinity.topologyKey` | string | `topology.kubernetes.io/zone` | Failure domain key |

### Ingress

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ingress.enabled` | bool | `false` | Enable Kubernetes Ingress |
| `ingress.className` | string | `""` | Ingress class (nginx, traefik, alb, gce) |
| `ingress.annotations` | map | `{}` | Ingress annotations (TLS, rate limits, etc.) |
| `ingress.hosts` | list | see values.yaml | Host and path routing rules |
| `ingress.tls` | list | `[]` | TLS secrets for HTTPS termination |

### Istio

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `istio.enabled` | bool | `false` | Enable Istio VirtualService |
| `istio.virtualService.hosts` | list | `[]` | VirtualService hostnames |
| `istio.virtualService.gateways` | list | `[]` | Gateway references (e.g., `istio-system/my-gateway`) |
| `istio.virtualService.http` | list | see values.yaml | HTTP routing rules (match, route, retries, timeout) |
| `istio.destinationRule.enabled` | bool | `false` | Enable DestinationRule |
| `istio.destinationRule.trafficPolicy` | map | `{}` | Connection pooling, load balancer, outlier detection |

### Extensibility

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `initContainers` | list | `[]` | Init containers (full container spec) |
| `extraContainers` | list | `[]` | Sidecar containers (full container spec) |
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
| `securityContext.readOnlyRootFilesystem` | bool | `true` | Read-only root FS (mount emptyDir for `/tmp` if needed) |
| `securityContext.capabilities.drop` | list | `[ALL]` | Drop all Linux capabilities |

### Observability

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `serviceMonitor.enabled` | bool | `false` | Create Prometheus ServiceMonitor |
| `serviceMonitor.interval` | string | `30s` | Scrape interval |
| `serviceMonitor.path` | string | `/metrics` | Metrics endpoint path |
| `serviceMonitor.port` | string | `http` | Port to scrape |

### Network Policy

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `networkPolicy.enabled` | bool | `false` | Create NetworkPolicy |
| `networkPolicy.ingress` | list | `[]` | Ingress rules (`from`, `ports`) |
| `networkPolicy.egress` | list | `[]` | Egress rules (`to`, `ports`) |

## How-To Guides

### Use with AWS EKS (IRSA + Secrets Manager)

1. Create an IAM role with Secrets Manager access
2. Associate OIDC provider with EKS cluster
3. Annotate the ServiceAccount for IRSA
4. Enable CSI secrets with the `aws` provider

```yaml
serviceAccount:
  create: true
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/MY_ROLE

secrets:
  csi:
    enabled: true
    provider: aws
    aws:
      secretArn: "arn:aws:secretsmanager:REGION:ACCOUNT:secret:my-secret"
      keys:
        - objectName: my-secret
          objectAlias: app-secret
          jmesPath:
            - path: db_password
              objectAlias: DB_PASSWORD
```

### Use with GCP GKE (Workload Identity)

```yaml
serviceAccount:
  create: true
  annotations:
    iam.gke.io/gcp-service-account: my-sa@project.iam.gserviceaccount.com

secrets:
  csi:
    enabled: true
    provider: gcp
    gcp:
      projectId: my-project
      secrets:
        - resourceName: "projects/my-project/secrets/db-pass/versions/latest"
          objectName: db-password
```

### Use with Azure AKS (Workload Identity + Key Vault)

```yaml
serviceAccount:
  create: true
  annotations:
    azure.workload.identity/client-id: "00000000-0000-0000-0000-000000000000"

secrets:
  csi:
    enabled: true
    provider: azure
    azure:
      keyvaultName: my-keyvault
      tenantId: "00000000-0000-0000-0000-000000000000"
      objects:
        - objectName: db-password
          objectType: secret
```

### Add a sidecar (e.g., Fluent Bit log shipper)

```yaml
extraContainers:
  - name: fluentbit
    image: fluent/fluent-bit:3.0
    volumeMounts:
      - name: shared-logs
        mountPath: /var/log/app
    resources:
      limits:
        cpu: 100m
        memory: 128Mi

extraVolumes:
  - name: shared-logs
    emptyDir: {}

extraVolumeMounts:
  - name: shared-logs
    mountPath: /var/log/app
```

### Wait for a dependency before starting

```yaml
initContainers:
  - name: wait-for-db
    image: busybox:1.36
    command:
      - sh
      - -c
      - |
        until nc -z postgres.database.svc.cluster.local 5432; do
          echo "Waiting for PostgreSQL..."
          sleep 2
        done
```

### Handle read-only root filesystem

If your application writes to `/tmp` or other paths, add emptyDir volumes:

```yaml
securityContext:
  readOnlyRootFilesystem: true

extraVolumes:
  - name: tmp
    emptyDir: {}
  - name: cache
    emptyDir: {}

extraVolumeMounts:
  - name: tmp
    mountPath: /tmp
  - name: cache
    mountPath: /var/cache
```

### Canary deployment with Istio traffic splitting

```yaml
istio:
  enabled: true
  virtualService:
    hosts: ["api.example.com"]
    gateways: ["istio-system/wildcard-gateway"]
    http:
      - route:
          - destination:
              port:
                number: 80
            weight: 90
          # Point the canary weight at a separate Helm release
```

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Pod in `CrashLoopBackOff` | Liveness probe path wrong or app slow to start | Adjust `probes.liveness.httpGet.path` or enable `probes.startup` with high `failureThreshold` |
| `readOnlyRootFilesystem` errors | App writes to `/tmp`, `/var`, or other paths | Add emptyDir volumes for writable paths (see How-To above) |
| CSI secrets not mounting | Provider not installed or wrong ARN | Verify `kubectl get csidrivers` shows `secrets-store.csi.k8s.io` and check SecretProviderClass |
| HPA not scaling | Metrics server not installed | Install `metrics-server` for CPU/memory or Prometheus adapter for custom metrics |
| ServiceMonitor not discovered | Label mismatch | Check Prometheus Operator's `serviceMonitorSelector` matches chart labels |
| Ingress 404 | Service port mismatch | Ensure `service.port` matches what Ingress expects |
| Pod pending, no nodes | Anti-affinity too strict | Switch `scheduling.podAntiAffinity.type` from `required` to `preferred` |
| Environment variables empty | ConfigMap not linked | Ensure `configMap.enabled: true` if using `configMap.data` |

## Resources Created

| Condition | Resource | API Version |
|-----------|----------|-------------|
| Always | Deployment | `apps/v1` |
| `service.enabled` | Service | `v1` |
| `serviceAccount.create` | ServiceAccount | `v1` |
| `autoscaling.enabled` | HorizontalPodAutoscaler | `autoscaling/v2` |
| `podDisruptionBudget.enabled` | PodDisruptionBudget | `policy/v1` |
| `configMap.enabled` | ConfigMap | `v1` |
| `ingress.enabled` | Ingress | `networking.k8s.io/v1` |
| `istio.enabled` | VirtualService | `networking.istio.io/v1beta1` |
| `istio.destinationRule.enabled` | DestinationRule | `networking.istio.io/v1beta1` |
| `secrets.csi.enabled` | SecretProviderClass | `secrets-store.csi.x-k8s.io/v1` |
| `serviceMonitor.enabled` | ServiceMonitor | `monitoring.coreos.com/v1` |
| `networkPolicy.enabled` | NetworkPolicy | `networking.k8s.io/v1` |
