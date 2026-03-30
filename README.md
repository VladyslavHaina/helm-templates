# Helm Templates

Production-ready, cloud-agnostic Helm charts for Kubernetes. Battle-tested patterns extracted from real-world infrastructure, generalized for community use.

## Philosophy

- **Values-driven**: Everything configurable from `values.yaml` — zero template editing required
- **Cloud-agnostic**: Support for AWS, GCP, Azure, and HashiCorp Vault where applicable
- **Istio-optional**: Service mesh integration available but never required
- **Independent charts**: Each chart is self-contained with no cross-chart dependencies
- **Production-ready**: Security contexts, PDB, health probes, resource limits, and monitoring built-in

## Charts

### Universal (every team needs these)

| Chart | Description |
|-------|-------------|
| [microservice](charts/microservice/) | Deployment, Service, HPA, PDB, Ingress, optional Istio, secrets management, observability |
| [statefulservice](charts/statefulservice/) | StatefulSet with headless Service, PVC templates, ordered startup, PDB |
| [worker](charts/worker/) | Job and CronJob for batch processing, migrations, and scheduled tasks |

### Infrastructure Patterns

| Chart | Description |
|-------|-------------|
| [argocd-application](charts/argocd-application/) | ArgoCD Application/AppProject with multi-source, sync-waves, RBAC |
| [istio-routing](charts/istio-routing/) | Gateway, VirtualService, DestinationRule, AuthorizationPolicy, PeerAuthentication |
| [network-policies](charts/network-policies/) | Default-deny baseline with configurable allow rules |
| [secrets-csi](charts/secrets-csi/) | Cloud-agnostic Secrets Store CSI Driver (AWS, Azure, GCP, Vault) |

### Complex Infrastructure

| Chart | Description |
|-------|-------------|
| [clickhouse-cluster](charts/clickhouse-cluster/) | ClickHouse via Altinity Operator with Keeper, RBAC, profiles, OTEL Collector |
| [kafka-connect](charts/kafka-connect/) | Kafka Connect with OTEL/JMX agents, connector monitoring sidecar, HPA |
| [flink-jobs](charts/flink-jobs/) | Apache Flink via Operator with FlinkDeployment and FlinkSessionJob |
| [mongodb-operator](charts/mongodb-operator/) | MongoDB Community Operator with replica sets, SCRAM auth, custom roles |
| [observability-stack](charts/observability-stack/) | OTEL Collector + ClickHouse + HyperDX/Grafana telemetry pipeline |

## Quick Start

```bash
# Install a chart
helm install my-release ./charts/microservice -f my-values.yaml

# Validate templates before installing
helm template my-release ./charts/microservice -f my-values.yaml

# Dry run
helm install my-release ./charts/microservice -f my-values.yaml --dry-run
```

## Requirements

- Kubernetes 1.26+
- Helm 3.12+

### Operator-based charts require their respective operators installed:

| Chart | Required Operator |
|-------|-------------------|
| clickhouse-cluster | [Altinity ClickHouse Operator](https://github.com/Altinity/clickhouse-operator) |
| flink-jobs | [Apache Flink Kubernetes Operator](https://nightlies.apache.org/flink/flink-kubernetes-operator-docs-stable/) |
| mongodb-operator | [MongoDB Community Operator](https://github.com/mongodb/mongodb-kubernetes-operator) |

### Optional integrations:

| Feature | Requirement |
|---------|-------------|
| Istio routing | [Istio](https://istio.io/) service mesh |
| CSI secrets | [Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/) + cloud provider |
| ServiceMonitor | [Prometheus Operator](https://prometheus-operator.dev/) |
| Network policies | CNI plugin with NetworkPolicy support (Calico, Cilium) |

## Cloud Provider Support

Charts that interact with cloud services (secrets, storage, identity) support:

| Provider | Identity Mechanism | Secrets Backend |
|----------|-------------------|-----------------|
| AWS | IRSA (IAM Roles for Service Accounts) | AWS Secrets Manager |
| GCP | Workload Identity | GCP Secret Manager |
| Azure | Workload Identity | Azure Key Vault |
| Vault | Kubernetes Auth | HashiCorp Vault |

## Values Convention

All charts follow a consistent values structure:

```yaml
# Identity & image
app:
  name: my-app
image:
  repository: nginx
  tag: "1.27"

# Compute
resources:
  limits: { cpu: 500m, memory: 512Mi }
  requests: { cpu: 100m, memory: 128Mi }

# Networking
service:
  enabled: true
  port: 80
ingress:
  enabled: false
istio:
  enabled: false

# Security
podSecurityContext:
  runAsNonRoot: true
securityContext:
  allowPrivilegeEscalation: false
secrets:
  csi:
    enabled: false
    provider: aws  # aws, azure, gcp, vault
serviceAccount:
  create: true

# Scheduling
scheduling:
  nodeSelector: {}
  tolerations: []
  podAntiAffinity:
    enabled: true

# Observability
serviceMonitor:
  enabled: false
probes:
  liveness:
    enabled: true
  readiness:
    enabled: true

# Resilience
autoscaling:
  enabled: false
podDisruptionBudget:
  enabled: false
networkPolicy:
  enabled: false
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run `helm lint charts/<chart-name>` and `helm template charts/<chart-name>`
5. Submit a pull request

## License

MIT
