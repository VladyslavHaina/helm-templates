# Helm Templates

Production-ready, cloud-agnostic Helm charts for Kubernetes. Battle-tested patterns extracted from real-world infrastructure, generalized for community use.

## Philosophy

- **Values-driven**: Everything configurable from `values.yaml` — zero template editing required
- **Cloud-agnostic**: Support for AWS, GCP, Azure, and HashiCorp Vault where applicable
- **Istio-optional**: Service mesh integration available but never required
- **Independent charts**: Each chart is self-contained with no cross-chart dependencies
- **Security-first**: Non-root containers, capability drops, RBAC, network policies, and secret management built-in
- **Production-ready**: PDB, health probes, resource limits, HPA, monitoring, and topology-aware scheduling

---

## Charts

### Universal Workload Charts

These three charts cover the vast majority of Kubernetes workloads.

| Chart | Kind | Use Case | Key Features |
|-------|------|----------|--------------|
| [microservice](charts/microservice/) | Deployment | HTTP APIs, web services, gRPC servers | HPA, PDB, Ingress, Istio VirtualService, ServiceMonitor, CSI secrets, configmap checksum |
| [statefulservice](charts/statefulservice/) | StatefulSet | Databases, caches, message brokers | Headless Service, PVC templates, ordered startup/shutdown, stable network IDs |
| [worker](charts/worker/) | Job / CronJob | Batch processing, migrations, ETL, scheduled cleanup | Parallelism, indexed completions, TTL cleanup, timezone-aware scheduling, suspend toggle |

### Infrastructure Charts

| Chart | Use Case | Key Features |
|-------|----------|--------------|
| [argocd-application](charts/argocd-application/) | GitOps deployment | Application + AppProject, multi-source, sync-waves, automated sync policies, RBAC |
| [istio-routing](charts/istio-routing/) | Traffic management | Gateway, VirtualService, DestinationRule, AuthorizationPolicy, PeerAuthentication (STRICT mTLS) |
| [network-policies](charts/network-policies/) | Network security | Default-deny ingress+egress baseline, DNS allow, monitoring allow, cross-namespace rules |
| [secrets-csi](charts/secrets-csi/) | Secret management | Secrets Store CSI Driver for AWS, Azure, GCP, Vault with optional K8s secret sync |

### Data & Streaming Charts

| Chart | Use Case | Key Features |
|-------|----------|--------------|
| [clickhouse-cluster](charts/clickhouse-cluster/) | OLAP database | Altinity Operator CRD, Keeper consensus, RBAC, profiles, quotas, OTEL Collector sidecar |
| [kafka-connect](charts/kafka-connect/) | Stream processing | SASL_SSL auth, OTEL/JMX agent init containers, connector health monitoring sidecar, auto-restart |
| [flink-jobs](charts/flink-jobs/) | Stream/batch compute | Flink Operator CRD, application + session mode, checkpointing, savepoints, HA |
| [mongodb-operator](charts/mongodb-operator/) | Document database | MongoDB Community Operator CRD, replica sets, SCRAM auth, custom roles, TLS, CDC support |
| [observability-stack](charts/observability-stack/) | Telemetry pipeline | OTEL Collector + configurable backend (ClickHouse/Elasticsearch) + UI (HyperDX/Grafana) |

---

## Architecture Overview

```
                        ┌─────────────────────────────────────────┐
                        │            GitOps Layer                 │
                        │  ┌──────────────────────────────────┐   │
                        │  │     argocd-application            │   │
                        │  │  (Application, AppProject, RBAC)  │   │
                        │  └──────────────────────────────────┘   │
                        └─────────────┬───────────────────────────┘
                                      │ deploys
          ┌───────────────────────────┼───────────────────────────┐
          │                           │                           │
          ▼                           ▼                           ▼
┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│   microservice   │    │ statefulservice  │    │     worker       │
│   (Deployment)   │    │  (StatefulSet)   │    │  (Job/CronJob)   │
└────────┬─────────┘    └────────┬─────────┘    └────────┬─────────┘
         │                       │                       │
         └───────────┬───────────┴───────────┬───────────┘
                     │                       │
          ┌──────────▼──────────┐  ┌─────────▼──────────┐
          │   istio-routing     │  │  network-policies   │
          │ (VirtualService,    │  │ (deny-all baseline, │
          │  Gateway, mTLS)     │  │  allow rules)       │
          └─────────────────────┘  └────────────────────┘
                     │
          ┌──────────▼──────────┐
          │    secrets-csi      │
          │ (AWS, Azure, GCP,   │
          │  Vault)             │
          └─────────────────────┘

          ┌─────────────────────────────────────────────┐
          │           Data & Streaming Layer             │
          │                                             │
          │  clickhouse-cluster  ←──  observability-stack│
          │  kafka-connect       ←──  flink-jobs         │
          │  mongodb-operator                           │
          └─────────────────────────────────────────────┘
```

---

## Quick Start

### Install a microservice

```bash
# Minimal — deploy with defaults
helm install my-api ./charts/microservice \
  --set app.name=my-api \
  --set image.repository=my-registry/my-api \
  --set image.tag=v1.0.0

# With custom values file
helm install my-api ./charts/microservice -f my-values.yaml

# Validate templates before installing
helm template my-api ./charts/microservice -f my-values.yaml

# Dry run with server-side validation
helm install my-api ./charts/microservice -f my-values.yaml --dry-run --debug
```

### Install a worker job

```bash
helm install db-migration ./charts/worker \
  --set app.name=db-migration \
  --set type=job \
  --set image.repository=my-registry/migrator \
  --set image.tag=v2.0.0 \
  --set command='{/bin/sh,-c,migrate up}'
```

### Install a CronJob

```bash
helm install cleanup ./charts/worker \
  --set app.name=cleanup \
  --set type=cronjob \
  --set cronjob.schedule="0 2 * * *" \
  --set image.repository=my-registry/cleanup \
  --set image.tag=v1.0.0
```

---

## Common Patterns

### Cloud Identity (IRSA / Workload Identity)

All workload charts support cloud provider identity annotations on the ServiceAccount:

```yaml
# AWS IRSA
serviceAccount:
  create: true
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789:role/my-role

# GCP Workload Identity
serviceAccount:
  create: true
  annotations:
    iam.gke.io/gcp-service-account: my-sa@my-project.iam.gserviceaccount.com

# Azure Workload Identity
serviceAccount:
  create: true
  annotations:
    azure.workload.identity/client-id: "00000000-0000-0000-0000-000000000000"
```

### Secrets Management (CSI Driver)

Mount secrets from any cloud provider without storing them in Kubernetes:

```yaml
secrets:
  csi:
    enabled: true
    provider: aws  # aws, azure, gcp, vault
    aws:
      secretArn: "arn:aws:secretsmanager:us-east-1:123456789:secret:my-secret"
      keys:
        - objectName: DB_PASSWORD
          objectType: secretsmanager
    # Optional: sync to a K8s Secret for envFrom usage
    syncAsKubernetesSecret:
      enabled: true
      secretName: my-app-secrets
      type: Opaque
      data:
        - objectName: DB_PASSWORD
          key: db-password
```

### Kubernetes Native Secrets

For environments without CSI Driver, mount standard K8s secrets:

```yaml
secrets:
  kubernetes:
    enabled: true
    name: my-app-secret
    mountPath: /mnt/secrets
    readOnly: true
```

### Istio Integration

Enable Istio routing on any workload chart:

```yaml
istio:
  enabled: true
  virtualService:
    hosts:
      - api.example.com
    gateways:
      - istio-system/main-gateway
    http:
      - match:
          - uri:
              prefix: /api/v1
        route:
          - destination:
              host: my-api
              port:
                number: 8080
```

### Network Policies (Zero-Trust)

The `network-policies` chart provides a deny-all baseline (both ingress and egress) with explicit allow rules:

```yaml
denyAllIngress:
  enabled: true

denyAllEgress:
  enabled: true

allowDNS:
  enabled: true  # always allow DNS resolution

allowSameNamespace:
  enabled: true  # allow pod-to-pod within namespace

allowFromMonitoring:
  enabled: true
  namespaceSelector:
    matchLabels:
      kubernetes.io/metadata.name: monitoring

allowEgressTo:
  enabled: true
  rules:
    - name: allow-database
      podSelector:
        matchLabels:
          app: my-api
      to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: database
      ports:
        - port: 5432
          protocol: TCP
```

### Autoscaling & Disruption Budgets

```yaml
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

podDisruptionBudget:
  enabled: true
  minAvailable: 2  # or use maxUnavailable: 1
```

### Pod Anti-Affinity

Spread pods across zones or nodes:

```yaml
scheduling:
  podAntiAffinity:
    enabled: true
    type: required   # required (hard) or preferred (soft)
    topologyKey: topology.kubernetes.io/zone
  nodeSelector:
    node-type: compute
  tolerations:
    - key: dedicated
      operator: Equal
      value: compute
      effect: NoSchedule
```

### Monitoring with Prometheus

```yaml
serviceMonitor:
  enabled: true
  interval: 30s
  path: /metrics
  port: http
  labels:
    release: prometheus  # match your Prometheus operator selector
```

---

## Security Defaults

All workload charts ship with production security defaults:

| Setting | Default | Chart Scope |
|---------|---------|-------------|
| `runAsNonRoot` | `true` | All workload charts |
| `allowPrivilegeEscalation` | `false` | All workload charts |
| `readOnlyRootFilesystem` | `true` (microservice, worker) / `false` (statefulservice) | Per chart |
| `capabilities.drop` | `[ALL]` | All workload charts |
| `seccompProfile.type` | `RuntimeDefault` | All workload charts |
| `automountServiceAccountToken` | `false` | All workload charts |

### Container Security Context

```yaml
podSecurityContext:
  runAsNonRoot: true
  seccompProfile:
    type: RuntimeDefault

securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop: [ALL]
```

---

## Values Convention

All charts follow a consistent values structure. Here is the full reference for universal workload charts:

```yaml
# ─── Identity & Image ───────────────────────────────────────────
app:
  name: my-app                    # Used for resource naming and labels

image:
  repository: nginx
  tag: "1.27"
  pullPolicy: IfNotPresent
  pullSecrets: []                 # imagePullSecrets for private registries

# ─── Compute ────────────────────────────────────────────────────
replicaCount: 2

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi

# ─── Networking ─────────────────────────────────────────────────
service:
  enabled: true
  type: ClusterIP
  port: 80

ingress:
  enabled: false
  className: nginx
  hosts: []
  tls: []

istio:
  enabled: false
  virtualService:
    hosts: []
    gateways: []

networkPolicy:
  enabled: false

# ─── Security ───────────────────────────────────────────────────
podSecurityContext:
  runAsNonRoot: true
  seccompProfile:
    type: RuntimeDefault

securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop: [ALL]

serviceAccount:
  create: true
  name: ""
  annotations: {}
  automountServiceAccountToken: false

# ─── Secrets ────────────────────────────────────────────────────
secrets:
  csi:
    enabled: false
    provider: ""                  # aws, azure, gcp, vault
  kubernetes:
    enabled: false
    name: ""
    mountPath: /mnt/secrets

# ─── Configuration ──────────────────────────────────────────────
configMap:
  enabled: false
  data: {}

env: []
envFrom: []

# ─── Scheduling ─────────────────────────────────────────────────
scheduling:
  nodeSelector: {}
  tolerations: []
  affinity: {}                    # Custom affinity (merged with podAntiAffinity)
  podAntiAffinity:
    enabled: true
    type: preferred               # preferred or required
    topologyKey: topology.kubernetes.io/zone

# ─── Observability ──────────────────────────────────────────────
probes:
  liveness:
    enabled: true
  readiness:
    enabled: true
  startup:
    enabled: false

serviceMonitor:
  enabled: false
  interval: 30s

# ─── Resilience ─────────────────────────────────────────────────
autoscaling:
  enabled: false
  minReplicas: 2
  maxReplicas: 10

podDisruptionBudget:
  enabled: false
  minAvailable: 1

# ─── Metadata ───────────────────────────────────────────────────
podAnnotations: {}
podLabels: {}
```

---

## Requirements

| Component | Version |
|-----------|---------|
| Kubernetes | 1.26+ |
| Helm | 3.12+ |

### Operator-Based Charts

These charts deploy CRDs that require their respective operators to be pre-installed:

| Chart | Required Operator | Installation |
|-------|-------------------|-------------|
| `clickhouse-cluster` | [Altinity ClickHouse Operator](https://github.com/Altinity/clickhouse-operator) | `kubectl apply -f https://raw.githubusercontent.com/Altinity/clickhouse-operator/master/deploy/operator/clickhouse-operator-install-bundle.yaml` |
| `flink-jobs` | [Apache Flink Kubernetes Operator](https://nightlies.apache.org/flink/flink-kubernetes-operator-docs-stable/) | `helm install flink-operator flink-operator-repo/flink-kubernetes-operator` |
| `mongodb-operator` | [MongoDB Community Operator](https://github.com/mongodb/mongodb-kubernetes-operator) | `helm install community-operator mongodb/community-operator` |

### Optional Integrations

| Feature | Requirement | Used By |
|---------|-------------|---------|
| Istio routing | [Istio](https://istio.io/) service mesh | microservice, statefulservice, kafka-connect, istio-routing |
| CSI secrets | [Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/) + cloud provider | microservice, statefulservice, worker, kafka-connect, secrets-csi |
| ServiceMonitor | [Prometheus Operator](https://prometheus-operator.dev/) | microservice, statefulservice, kafka-connect, mongodb-operator |
| Network policies | CNI with NetworkPolicy support (Calico, Cilium) | network-policies, microservice, statefulservice |
| ArgoCD | [Argo CD](https://argo-cd.readthedocs.io/) | argocd-application |

---

## Cloud Provider Support

| Provider | Identity Mechanism | Secrets Backend | Example |
|----------|-------------------|-----------------|---------|
| AWS | IRSA (IAM Roles for Service Accounts) | AWS Secrets Manager | [aws-irsa-istio.yaml](charts/microservice/examples/aws-irsa-istio.yaml) |
| GCP | Workload Identity | GCP Secret Manager | [gcp-workload-identity.yaml](charts/microservice/examples/gcp-workload-identity.yaml) |
| Azure | Workload Identity | Azure Key Vault | [azure-workload-identity.yaml](charts/microservice/examples/azure-workload-identity.yaml) |
| Vault | Kubernetes Auth | HashiCorp Vault | [hashicorp-vault.yaml](charts/secrets-csi/examples/hashicorp-vault.yaml) |

---

## Examples

Every chart includes example values files for common scenarios:

### Microservice

| Example | Description |
|---------|-------------|
| [basic.yaml](charts/microservice/examples/basic.yaml) | Minimal deployment with service and probes |
| [full-featured.yaml](charts/microservice/examples/full-featured.yaml) | HPA, PDB, Ingress, NetworkPolicy, ConfigMap, monitoring, topology spread |
| [aws-irsa-istio.yaml](charts/microservice/examples/aws-irsa-istio.yaml) | AWS IRSA + Istio VirtualService + CSI secrets |
| [gcp-workload-identity.yaml](charts/microservice/examples/gcp-workload-identity.yaml) | GCP Workload Identity + CSI secrets |
| [azure-workload-identity.yaml](charts/microservice/examples/azure-workload-identity.yaml) | Azure Workload Identity + CSI secrets |
| [with-monitoring.yaml](charts/microservice/examples/with-monitoring.yaml) | ServiceMonitor + init containers |
| [with-init-containers.yaml](charts/microservice/examples/with-init-containers.yaml) | Multi-container patterns |

### Worker

| Example | Description |
|---------|-------------|
| [batch-job.yaml](charts/worker/examples/batch-job.yaml) | One-time job with parallelism |
| [scheduled-cleanup.yaml](charts/worker/examples/scheduled-cleanup.yaml) | CronJob with timezone support |
| [migration.yaml](charts/worker/examples/migration.yaml) | Database migration job |
| [etl-pipeline.yaml](charts/worker/examples/etl-pipeline.yaml) | ETL batch processing |

### Kafka Connect

| Example | Description |
|---------|-------------|
| [basic.yaml](charts/kafka-connect/examples/basic.yaml) | Minimal Kafka Connect cluster |
| [production.yaml](charts/kafka-connect/examples/production.yaml) | SASL_SSL, OTEL, JMX, HPA, connector monitoring |
| [debezium-cdc.yaml](charts/kafka-connect/examples/debezium-cdc.yaml) | CDC with Debezium MongoDB connector |
| [s3-sink.yaml](charts/kafka-connect/examples/s3-sink.yaml) | S3 sink connector |
| [snowflake-sink.yaml](charts/kafka-connect/examples/snowflake-sink.yaml) | Snowflake sink connector |
| [multi-connector-pipeline.yaml](charts/kafka-connect/examples/multi-connector-pipeline.yaml) | Multiple connectors in one cluster |
| [with-schema-registry.yaml](charts/kafka-connect/examples/with-schema-registry.yaml) | Avro with Schema Registry |

### Network Policies

| Example | Description |
|---------|-------------|
| [basic-deny-all.yaml](charts/network-policies/examples/basic-deny-all.yaml) | Deny all ingress and egress |
| [production-baseline.yaml](charts/network-policies/examples/production-baseline.yaml) | Production zero-trust setup |
| [with-cross-namespace.yaml](charts/network-policies/examples/with-cross-namespace.yaml) | Cross-namespace communication rules |
| [egress-restricted.yaml](charts/network-policies/examples/egress-restricted.yaml) | Strict egress control |

### Secrets CSI

| Example | Description |
|---------|-------------|
| [aws-secrets-manager.yaml](charts/secrets-csi/examples/aws-secrets-manager.yaml) | AWS Secrets Manager integration |
| [azure-key-vault.yaml](charts/secrets-csi/examples/azure-key-vault.yaml) | Azure Key Vault integration |
| [gcp-secret-manager.yaml](charts/secrets-csi/examples/gcp-secret-manager.yaml) | GCP Secret Manager integration |
| [hashicorp-vault.yaml](charts/secrets-csi/examples/hashicorp-vault.yaml) | HashiCorp Vault integration |

> See each chart's `examples/` directory for the complete list.

---

## Choosing the Right Chart

```
Is your workload...
│
├── A long-running process serving HTTP/gRPC?
│   └── Use: microservice
│
├── A long-running process needing stable storage/identity?
│   └── Use: statefulservice
│
├── A one-time or scheduled batch task?
│   └── Use: worker (type: job or cronjob)
│
├── A Kafka Connect cluster?
│   └── Use: kafka-connect
│
├── A Flink job (streaming or batch)?
│   └── Use: flink-jobs
│
├── A MongoDB replica set?
│   └── Use: mongodb-operator
│
├── A ClickHouse analytics cluster?
│   └── Use: clickhouse-cluster
│
└── An observability pipeline (logs/traces/metrics)?
    └── Use: observability-stack
```

---

## Troubleshooting

### Common Issues

**Pods stuck in `CreateContainerConfigError`**

Usually a missing secret reference. Check:
```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl get secretproviderclass -n <namespace>
```

**Pods stuck in `Pending`**

Check scheduling constraints:
```bash
kubectl describe pod <pod-name> -n <namespace> | grep -A5 Events
# Common causes: insufficient resources, nodeSelector mismatch, required anti-affinity
```

**Helm install fails with "kubeVersion constraint not met"**

These charts require Kubernetes 1.26+. Check your cluster version:
```bash
kubectl version --short
```

**NetworkPolicy blocking traffic**

The `network-policies` chart defaults to deny-all for both ingress and egress. Ensure you have:
1. `allowDNS.enabled: true` (default) for DNS resolution
2. Explicit `allowEgressTo` rules for your service dependencies
3. `allowFromNamespaces` or `allowSameNamespace` for inbound traffic

**CRD-based charts fail with "no matches for kind"**

Install the required operator first:
```bash
# Check if CRDs exist
kubectl get crd | grep clickhouse     # for clickhouse-cluster
kubectl get crd | grep flink          # for flink-jobs
kubectl get crd | grep mongodb        # for mongodb-operator
```

### Debugging Templates

```bash
# Render templates locally without installing
helm template my-release ./charts/microservice -f my-values.yaml

# Render a specific template
helm template my-release ./charts/microservice -f my-values.yaml --show-only templates/deployment.yaml

# Validate against the cluster API
helm install my-release ./charts/microservice -f my-values.yaml --dry-run --debug

# Check installed release status
helm status my-release -n <namespace>
helm get values my-release -n <namespace>
helm get manifest my-release -n <namespace>
```

---

## Repository Structure

```
helm-templates/
├── README.md                          # This file
├── charts/
│   ├── microservice/                  # Deployment-based workloads
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   ├── templates/
│   │   │   ├── _helpers.tpl           # Shared template functions
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   ├── hpa.yaml
│   │   │   ├── pdb.yaml
│   │   │   ├── ingress.yaml
│   │   │   ├── configmap.yaml
│   │   │   ├── serviceaccount.yaml
│   │   │   ├── servicemonitor.yaml
│   │   │   ├── secretproviderclass.yaml
│   │   │   ├── virtualservice.yaml
│   │   │   ├── destinationrule.yaml
│   │   │   └── NOTES.txt
│   │   └── examples/
│   ├── statefulservice/               # StatefulSet-based workloads
│   ├── worker/                        # Job and CronJob workloads
│   ├── argocd-application/            # ArgoCD GitOps
│   ├── istio-routing/                 # Istio traffic management
│   ├── network-policies/              # Kubernetes NetworkPolicy
│   ├── secrets-csi/                   # Secrets Store CSI Driver
│   ├── clickhouse-cluster/            # ClickHouse via Altinity Operator
│   ├── kafka-connect/                 # Kafka Connect cluster
│   ├── flink-jobs/                    # Apache Flink via Operator
│   ├── mongodb-operator/              # MongoDB via Community Operator
│   └── observability-stack/           # OTEL + storage + UI
└── .helmignore
```

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feat/my-feature`)
3. Make your changes
4. Lint and validate:
   ```bash
   helm lint charts/<chart-name>
   helm template test-release charts/<chart-name> -f charts/<chart-name>/examples/basic.yaml
   ```
5. If adding a new chart, include:
   - `Chart.yaml` with `kubeVersion: ">=1.26.0-0"`
   - `values.yaml` with documented defaults
   - `templates/_helpers.tpl` following the standard helper pattern
   - `templates/NOTES.txt` with post-install instructions
   - At least 3 examples (`basic.yaml`, `production.yaml`, and one scenario-specific)
   - `README.md` with architecture, features, configuration reference, and troubleshooting
6. Submit a pull request

---

## License

MIT
