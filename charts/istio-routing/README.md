# Istio Routing Chart

Helm chart for managing Istio traffic routing resources declaratively. Provides a single point of configuration for Gateways, VirtualServices, DestinationRules, AuthorizationPolicies, PeerAuthentication, and Sidecar resources, enabling teams to define ingress routing, canary deployments, connection pooling, mTLS enforcement, and egress scope in one values file.

## Architecture

```
                    ┌──────────────────────────────┐
                    │      Kubernetes Cluster       │
                    │                              │
  ┌─────────┐      │  ┌────────────────────────┐  │
  │ External │──────│──│  Gateway               │  │
  │ Traffic  │      │  │  (TLS + HTTPS redirect)│  │
  └─────────┘      │  └────────┬───────────────┘  │
                    │           │                  │
                    │  ┌───────▼────────────────┐  │
                    │  │  VirtualService(s)      │  │
                    │  │  - path matching        │  │
                    │  │  - traffic splitting    │  │
                    │  │  - retries / timeouts   │  │
                    │  └────────┬───────────────┘  │
                    │           │                  │
                    │  ┌───────▼────────────────┐  │
                    │  │  DestinationRule(s)     │  │
                    │  │  - connection pool      │  │
                    │  │  - outlier detection    │  │
                    │  │  - subsets (v1, v2)     │  │
                    │  └────────────────────────┘  │
                    │                              │
                    │  ┌──────┐ ┌──────┐ ┌──────┐ │
                    │  │AuthZ │ │mTLS  │ │Sidecar│ │
                    │  │Policy│ │PeerA │ │Egress │ │
                    │  └──────┘ └──────┘ └──────┘ │
                    └──────────────────────────────┘
```

## Features

| Feature | Description | Enabled by |
|---------|-------------|-----------|
| Gateway | Shared ingress gateway with TLS termination and HTTPS redirect | `gateway.enabled` |
| VirtualService | Path-based routing, retries, timeouts, traffic splitting | `virtualServices` list |
| DestinationRule | Connection pooling, load balancing, outlier detection, subsets | `destinationRules` list |
| AuthorizationPolicy | Namespace, method, and path-level access control | `authorizationPolicies` list |
| PeerAuthentication | mTLS mode enforcement (STRICT, PERMISSIVE, DISABLE) | `peerAuthentication.enabled` |
| Sidecar | Egress scope restriction to limit mesh reachability | `sidecar.enabled` |

## Prerequisites

- Kubernetes 1.26+
- Helm 3.12+
- [Istio](https://istio.io/) service mesh installed

### Optional dependencies

| Feature | Requires |
|---------|----------|
| Gateway | Istio ingress gateway deployment (`istio-ingressgateway`) |
| TLS termination | TLS certificate stored as a Kubernetes Secret (referenced by `credentialName`) |
| Authorization policies | Istio 1.16+ for CUSTOM action type |

## Quick Start

```bash
# Deploy basic routing
helm install my-routing ./charts/istio-routing \
  --set virtualServices[0].name=my-svc \
  --set virtualServices[0].hosts[0]=my-svc.example.com

# With a values file
helm install my-routing ./charts/istio-routing -f my-values.yaml

# Dry run to inspect output
helm template my-routing ./charts/istio-routing -f my-values.yaml
```

## Examples

| File | Use Case | Features Demonstrated |
|------|----------|----------------------|
| [simple-routing.yaml](examples/simple-routing.yaml) | Basic VirtualService | Path-based routing, retries, timeouts |
| [canary-deployment.yaml](examples/canary-deployment.yaml) | Traffic splitting (90/10) | Weighted routing, subsets, DestinationRule |
| [multi-service-gateway.yaml](examples/multi-service-gateway.yaml) | Shared gateway, multiple services | Gateway with TLS, multiple VirtualServices |
| [full-security.yaml](examples/full-security.yaml) | mTLS + AuthorizationPolicy | PeerAuthentication, AuthorizationPolicy, Sidecar |

## Configuration Reference

### Global

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `nameOverride` | string | `""` | Override chart name |
| `fullnameOverride` | string | `""` | Override full release name |

### Gateway

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `gateway.enabled` | bool | `false` | Create an Istio Gateway |
| `gateway.name` | string | `my-gateway` | Gateway resource name |
| `gateway.selector` | map | `{istio: ingressgateway}` | Label selector for the gateway workload |
| `gateway.servers` | list | see values.yaml | Server entries (port, TLS, hosts) |
| `gateway.servers[].port.number` | int | - | Port number (e.g., 443, 80) |
| `gateway.servers[].port.name` | string | - | Port name (e.g., https, http) |
| `gateway.servers[].port.protocol` | string | - | Protocol (HTTPS, HTTP, TCP) |
| `gateway.servers[].tls.mode` | string | - | TLS mode (SIMPLE, MUTUAL, PASSTHROUGH) |
| `gateway.servers[].tls.credentialName` | string | - | K8s Secret containing TLS certificate |
| `gateway.servers[].tls.httpsRedirect` | bool | - | Redirect HTTP to HTTPS |
| `gateway.servers[].hosts` | list | - | Hostnames served by this port |

### VirtualServices

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `virtualServices` | list | see values.yaml | List of VirtualService resources |
| `virtualServices[].name` | string | - | VirtualService resource name |
| `virtualServices[].hosts` | list | - | Hostnames to match |
| `virtualServices[].gateways` | list | - | Gateway references (e.g., `istio-system/my-gateway`) |
| `virtualServices[].http` | list | - | HTTP routing rules |
| `virtualServices[].http[].match` | list | - | Match conditions (uri, headers, etc.) |
| `virtualServices[].http[].match[].uri.prefix` | string | - | URI prefix match |
| `virtualServices[].http[].route` | list | - | Routing destinations |
| `virtualServices[].http[].route[].destination.host` | string | - | Target service hostname |
| `virtualServices[].http[].route[].destination.port.number` | int | - | Target service port |
| `virtualServices[].http[].route[].weight` | int | - | Traffic weight (for splitting) |
| `virtualServices[].http[].timeout` | string | - | Request timeout (e.g., `30s`) |
| `virtualServices[].http[].retries.attempts` | int | - | Number of retry attempts |
| `virtualServices[].http[].retries.perTryTimeout` | string | - | Timeout per retry attempt |
| `virtualServices[].http[].retries.retryOn` | string | - | Retry conditions (e.g., `5xx,reset,connect-failure`) |

### DestinationRules

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `destinationRules` | list | `[]` | List of DestinationRule resources |
| `destinationRules[].name` | string | - | DestinationRule resource name |
| `destinationRules[].host` | string | - | Target service hostname |
| `destinationRules[].trafficPolicy.connectionPool.tcp.maxConnections` | int | - | Max TCP connections |
| `destinationRules[].trafficPolicy.connectionPool.http.h2UpgradePolicy` | string | - | HTTP/2 upgrade policy |
| `destinationRules[].trafficPolicy.connectionPool.http.http1MaxPendingRequests` | int | - | Max pending HTTP/1.1 requests |
| `destinationRules[].trafficPolicy.connectionPool.http.http2MaxRequests` | int | - | Max HTTP/2 requests |
| `destinationRules[].trafficPolicy.loadBalancer.simple` | string | - | Load balancer algorithm (ROUND_ROBIN, LEAST_CONN, RANDOM) |
| `destinationRules[].trafficPolicy.outlierDetection.consecutive5xxErrors` | int | - | Errors before ejection |
| `destinationRules[].trafficPolicy.outlierDetection.interval` | string | - | Ejection analysis interval |
| `destinationRules[].trafficPolicy.outlierDetection.baseEjectionTime` | string | - | Minimum ejection duration |
| `destinationRules[].trafficPolicy.outlierDetection.maxEjectionPercent` | int | - | Max ejected host percentage |
| `destinationRules[].subsets` | list | `[]` | Named subsets with label selectors |
| `destinationRules[].subsets[].name` | string | - | Subset name (e.g., v1, v2) |
| `destinationRules[].subsets[].labels` | map | - | Pod labels for subset selection |

### AuthorizationPolicies

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `authorizationPolicies` | list | `[]` | List of AuthorizationPolicy resources |
| `authorizationPolicies[].name` | string | - | Policy name |
| `authorizationPolicies[].action` | string | - | Action: `ALLOW`, `DENY`, or `CUSTOM` |
| `authorizationPolicies[].rules` | list | - | Authorization rules |
| `authorizationPolicies[].rules[].from[].source.namespaces` | list | - | Allowed source namespaces |
| `authorizationPolicies[].rules[].to[].operation.methods` | list | - | Allowed HTTP methods |
| `authorizationPolicies[].rules[].to[].operation.paths` | list | - | Allowed request paths |

### PeerAuthentication

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `peerAuthentication.enabled` | bool | `false` | Create PeerAuthentication resource |
| `peerAuthentication.mtls.mode` | string | `STRICT` | mTLS mode: `STRICT`, `PERMISSIVE`, or `DISABLE` |

### Sidecar

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `sidecar.enabled` | bool | `false` | Create Sidecar resource |
| `sidecar.egress` | list | see values.yaml | Egress listener configuration |
| `sidecar.egress[].hosts` | list | `["./*", "istio-system/*"]` | Hosts reachable from the sidecar |

## How-To Guides

### Set up a shared Gateway with TLS and HTTPS redirect

```yaml
gateway:
  enabled: true
  name: wildcard-gateway
  selector:
    istio: ingressgateway
  servers:
    - port:
        number: 443
        name: https
        protocol: HTTPS
      tls:
        mode: SIMPLE
        credentialName: wildcard-tls-cert
      hosts:
        - "*.example.com"
    - port:
        number: 80
        name: http
        protocol: HTTP
      tls:
        httpsRedirect: true
      hosts:
        - "*.example.com"
```

### Canary deployment with 90/10 traffic split

```yaml
virtualServices:
  - name: my-api
    hosts: ["api.example.com"]
    gateways: ["istio-system/wildcard-gateway"]
    http:
      - route:
          - destination:
              host: my-api-stable
              port:
                number: 8080
            weight: 90
          - destination:
              host: my-api-canary
              port:
                number: 8080
            weight: 10

destinationRules:
  - name: my-api-dr
    host: my-api-stable
    trafficPolicy:
      outlierDetection:
        consecutive5xxErrors: 3
        interval: 10s
        baseEjectionTime: 30s
```

### Enforce strict mTLS with namespace-level AuthorizationPolicy

```yaml
peerAuthentication:
  enabled: true
  mtls:
    mode: STRICT

authorizationPolicies:
  - name: allow-frontend-only
    action: ALLOW
    rules:
      - from:
          - source:
              namespaces: ["frontend"]
        to:
          - operation:
              methods: ["GET", "POST"]
              paths: ["/api/*"]
```

### Restrict sidecar egress scope

```yaml
sidecar:
  enabled: true
  egress:
    - hosts:
        - "./*"
        - "istio-system/*"
        - "monitoring/*"
```

### Configure connection pooling and outlier detection

```yaml
destinationRules:
  - name: high-traffic-dr
    host: my-api
    trafficPolicy:
      connectionPool:
        tcp:
          maxConnections: 200
        http:
          h2UpgradePolicy: DEFAULT
          http1MaxPendingRequests: 200
          http2MaxRequests: 2000
      loadBalancer:
        simple: LEAST_CONN
      outlierDetection:
        consecutive5xxErrors: 5
        interval: 30s
        baseEjectionTime: 60s
        maxEjectionPercent: 30
```

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| 404 from Gateway | VirtualService hosts or gateways do not match Gateway | Ensure `virtualServices[].gateways` references the correct Gateway and hosts overlap |
| 503 upstream errors | DestinationRule outlier detection ejecting all hosts | Reduce `consecutive5xxErrors` threshold or increase `maxEjectionPercent` |
| mTLS handshake failure | Mismatched PeerAuthentication modes across namespaces | Set `PERMISSIVE` during migration, then switch to `STRICT` when all sidecars are injected |
| Traffic split not working | Weights do not sum to 100 | Ensure all `weight` values in a route add up to exactly 100 |
| AuthorizationPolicy blocks all traffic | Missing `rules` field creates a deny-all policy | Always specify at least one rule when `action: ALLOW` |
| Gateway TLS error | Missing or expired TLS secret | Verify `credentialName` Secret exists in the `istio-system` namespace with valid certs |
| Sidecar limits breaking service calls | Egress hosts too restrictive | Add required namespaces to `sidecar.egress[].hosts` |

## Resources Created

| Condition | Resource | API Version |
|-----------|----------|-------------|
| `gateway.enabled` | Gateway | `networking.istio.io/v1beta1` |
| Per `virtualServices[]` entry | VirtualService | `networking.istio.io/v1beta1` |
| Per `destinationRules[]` entry | DestinationRule | `networking.istio.io/v1beta1` |
| Per `authorizationPolicies[]` entry | AuthorizationPolicy | `security.istio.io/v1` |
| `peerAuthentication.enabled` | PeerAuthentication | `security.istio.io/v1` |
| `sidecar.enabled` | Sidecar | `networking.istio.io/v1beta1` |
