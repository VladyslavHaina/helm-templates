# Network Policies

Kubernetes NetworkPolicy chart that establishes a default-deny zero-trust baseline and layers configurable allow rules on top. It covers ingress and egress deny-all policies, same-namespace communication, monitoring access for Prometheus scraping, service mesh integration, DNS egress, cross-namespace rules, and arbitrary custom policies passed through as full spec objects.

## Architecture

```
                          ┌─────────────────────────┐
                          │   Target Namespace       │
                          │                          │
  ┌────────────┐   deny   │  ┌────────────────────┐ │
  │ External   │────X─────│─>│  All Pods           │ │
  │ Traffic    │          │  │  (denyAllIngress)   │ │
  └────────────┘          │  └────────┬───────────┘ │
                          │           │              │
  ┌────────────┐  allow   │           │ allow        │
  │ monitoring │──────────│──> port 9090  (same-ns) │
  │ namespace  │          │           │              │
  └────────────┘          │           v              │
                          │  ┌────────────────────┐ │
  ┌────────────┐  allow   │  │  DNS (kube-system)  │ │
  │ istio-     │──────────│──> port 53 UDP/TCP     │ │
  │ system     │          │  └────────────────────┘ │
  └────────────┘          │                          │
                          │  ┌────────────────────┐ │
  ┌────────────┐  custom  │  │  Egress targets     │ │
  │ frontend   │──────────│──> (allowEgressTo)     │ │
  │ namespace  │          │  └────────────────────┘ │
  └────────────┘          └─────────────────────────┘
```

## Features

| Feature | Description | Enabled by |
|---------|-------------|------------|
| Default deny ingress | Block all inbound traffic as a zero-trust foundation | `denyAllIngress.enabled` |
| Default deny egress | Block all outbound traffic | `denyAllEgress.enabled` |
| Same-namespace allow | Permit pod-to-pod traffic within the namespace | `allowSameNamespace.enabled` |
| Monitoring ingress | Allow Prometheus scraping from monitoring namespace | `allowFromMonitoring.enabled` |
| Service mesh ingress | Allow traffic from Istio or Linkerd namespace | `allowFromServiceMesh.enabled` |
| DNS egress | Allow UDP/TCP port 53 to kube-system for service discovery | `allowDNS.enabled` |
| Cross-namespace ingress | Allow traffic from an arbitrary list of namespaces | `allowFromNamespaces[]` |
| Selective egress | Allow egress to specific namespace/pod/port targets | `allowEgressTo[]` |
| Custom policies | Full NetworkPolicy spec passthrough for advanced use cases | `customPolicies[]` |

## Prerequisites

| Requirement | Minimum Version | Notes |
|-------------|-----------------|-------|
| Kubernetes | 1.24+ | NetworkPolicy API must be available |
| Helm | 3.10+ | |
| CNI plugin | -- | Must support NetworkPolicy (Calico, Cilium, Antrea, or similar) |

## Quick Start

```bash
helm repo add my-charts https://charts.example.com
helm repo update
helm install net-pol my-charts/network-policies -n my-app --create-namespace
```

## Examples

| File | Use Case | Features Demonstrated |
|------|----------|----------------------|
| [basic-deny-all.yaml](examples/basic-deny-all.yaml) | Minimal lockdown | Default deny ingress + same-namespace allow |
| [production-baseline.yaml](examples/production-baseline.yaml) | Full production policy set | Deny ingress, monitoring, DNS, service mesh |
| [with-cross-namespace.yaml](examples/with-cross-namespace.yaml) | Multi-namespace architectures | `allowFromNamespaces` with port restrictions |
| [egress-restricted.yaml](examples/egress-restricted.yaml) | Egress lockdown | Deny all egress + selective `allowEgressTo` |

## Configuration Reference

### General

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `nameOverride` | string | `""` | Override the chart name |
| `fullnameOverride` | string | `""` | Override the full release name |

### Deny All Ingress

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `denyAllIngress.enabled` | bool | `true` | Create a deny-all ingress NetworkPolicy |

### Deny All Egress

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `denyAllEgress.enabled` | bool | `false` | Create a deny-all egress NetworkPolicy |

### Allow Same Namespace

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `allowSameNamespace.enabled` | bool | `true` | Allow pod-to-pod traffic within the same namespace |

### Allow From Monitoring

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `allowFromMonitoring.enabled` | bool | `true` | Allow ingress from the monitoring namespace |
| `allowFromMonitoring.namespaceLabel.key` | string | `kubernetes.io/metadata.name` | Label key used to select the monitoring namespace |
| `allowFromMonitoring.namespaceLabel.value` | string | `monitoring` | Label value used to select the monitoring namespace |
| `allowFromMonitoring.ports` | list | `[]` | Restrict to specific ports; empty means all ports |

### Allow From Service Mesh

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `allowFromServiceMesh.enabled` | bool | `false` | Allow ingress from the service mesh namespace |
| `allowFromServiceMesh.namespaceLabel.key` | string | `kubernetes.io/metadata.name` | Label key used to select the mesh namespace |
| `allowFromServiceMesh.namespaceLabel.value` | string | `istio-system` | Label value used to select the mesh namespace |

### Allow DNS

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `allowDNS.enabled` | bool | `true` | Allow DNS egress to kube-system |
| `allowDNS.namespaceLabel.key` | string | `kubernetes.io/metadata.name` | Label key for kube-system namespace |
| `allowDNS.namespaceLabel.value` | string | `kube-system` | Label value for kube-system namespace |
| `allowDNS.port` | int | `53` | DNS port |

### Allow From Namespaces

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `allowFromNamespaces` | list | `[]` | List of cross-namespace ingress rules |
| `allowFromNamespaces[].name` | string | -- | Name for the NetworkPolicy resource |
| `allowFromNamespaces[].namespaceSelector` | object | -- | Namespace selector with matchLabels |
| `allowFromNamespaces[].podSelector` | object | -- | Pod selector within the source namespace |
| `allowFromNamespaces[].ports` | list | -- | Allowed ports (port, protocol) |

### Allow Egress To

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `allowEgressTo` | list | `[]` | List of selective egress rules |
| `allowEgressTo[].name` | string | -- | Name for the NetworkPolicy resource |
| `allowEgressTo[].namespaceSelector` | object | -- | Target namespace selector |
| `allowEgressTo[].podSelector` | object | -- | Target pod selector |
| `allowEgressTo[].ports` | list | -- | Allowed ports (port, protocol) |

### Custom Policies

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `customPolicies` | list | `[]` | List of full NetworkPolicy spec passthroughs |
| `customPolicies[].name` | string | -- | Name for the NetworkPolicy resource |
| `customPolicies[].spec` | object | -- | Complete NetworkPolicy spec (podSelector, ingress, egress, policyTypes) |

## How-To Guides

### Allow a frontend namespace to reach backend pods on port 8080

```yaml
allowFromNamespaces:
  - name: allow-frontend
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: frontend
    podSelector: {}
    ports:
      - port: 8080
        protocol: TCP
```

### Restrict egress to a database namespace

```yaml
denyAllEgress:
  enabled: true
allowDNS:
  enabled: true
allowEgressTo:
  - name: allow-to-db
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: database
    podSelector:
      matchLabels:
        app: postgresql
    ports:
      - port: 5432
        protocol: TCP
```

### Allow Prometheus to scrape only specific metrics ports

```yaml
allowFromMonitoring:
  enabled: true
  ports:
    - port: 9090
      protocol: TCP
    - port: 9404
      protocol: TCP
```

### Add a custom IP-block-based policy

```yaml
customPolicies:
  - name: allow-corporate-vpn
    spec:
      podSelector:
        matchLabels:
          app: admin-panel
      ingress:
        - from:
            - ipBlock:
                cidr: 10.0.0.0/8
      policyTypes:
        - Ingress
```

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| All pods lose connectivity after install | `denyAllIngress` is true but required allow rules are disabled | Enable `allowSameNamespace` and `allowDNS` |
| DNS resolution fails | `allowDNS.enabled` is false or egress deny is on without DNS allow | Set `allowDNS.enabled: true` |
| Prometheus cannot scrape targets | `allowFromMonitoring.enabled` is false or namespace label mismatch | Verify label key/value match actual monitoring namespace labels |
| Service mesh sidecar injection fails | `allowFromServiceMesh` is disabled | Enable and verify the mesh namespace label |
| Cross-namespace traffic blocked despite rule | `namespaceSelector.matchLabels` do not match actual namespace labels | Run `kubectl get ns --show-labels` to confirm label values |
| Egress to external APIs fails | `denyAllEgress` is enabled without a matching `allowEgressTo` entry | Add an egress rule for the external destination CIDR |

## Resources Created

| Condition | Resource | API Version |
|-----------|----------|-------------|
| `denyAllIngress.enabled` | NetworkPolicy (deny-all-ingress) | networking.k8s.io/v1 |
| `denyAllEgress.enabled` | NetworkPolicy (deny-all-egress) | networking.k8s.io/v1 |
| `allowSameNamespace.enabled` | NetworkPolicy (allow-same-ns) | networking.k8s.io/v1 |
| `allowFromMonitoring.enabled` | NetworkPolicy (allow-from-monitoring) | networking.k8s.io/v1 |
| `allowFromServiceMesh.enabled` | NetworkPolicy (allow-from-service-mesh) | networking.k8s.io/v1 |
| `allowDNS.enabled` | NetworkPolicy (allow-dns) | networking.k8s.io/v1 |
| `allowFromNamespaces` has entries | NetworkPolicy (per entry) | networking.k8s.io/v1 |
| `allowEgressTo` has entries | NetworkPolicy (per entry) | networking.k8s.io/v1 |
| `customPolicies` has entries | NetworkPolicy (per entry) | networking.k8s.io/v1 |
