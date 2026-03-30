# MongoDB Operator

Helm chart for deploying MongoDB replica sets on Kubernetes via the MongoDB Community Operator. Provides declarative MongoDBCommunity custom resources with SCRAM authentication, custom roles (including CDC/Change Stream access for Debezium), optional TLS, WiredTiger tuning, Prometheus monitoring via an exporter sidecar, pod anti-affinity for zone-spreading, and a per-service database pattern for microservice isolation.

## Architecture

```
+------------------+       +-------------------------+
|  Helm Release    | ----> | MongoDBCommunity CR     |
|  (this chart)    |       +------------+------------+
+------------------+                    |
        |                               | watched by
        |                               v
        |                  +-------------------------+
        |                  | MongoDB Community       |
        |                  | Operator (pre-installed)|
        |                  +------------+------------+
        |                               |
        |                               | creates & manages
        |          +--------------------+--------------------+
        |          |                    |                    |
        |          v                    v                    v
        |   +-----------+       +-----------+       +-----------+
        |   | mongod-0  |<----->| mongod-1  |<----->| mongod-2  |
        |   | (primary) |  rs   | (secondary)|  rs  | (secondary)|
        |   +-----+-----+       +-----------+       +-----------+
        |         |
        |         v
        |   +------------------+     +-----------------+
        +-->| ServiceMonitor   |     | NetworkPolicy   |
            | (Prometheus)     |     | (optional)      |
            +------------------+     +-----------------+
                    ^
                    |
            +-------+--------+
            | mongodb_exporter|
            | (sidecar)      |
            +----------------+
```

## Features

| Feature | Description | Enabled by |
|---------|-------------|------------|
| Replica set | Multi-member MongoDB replica set with automatic elections | `replicaSet.members` |
| SCRAM authentication | Username/password authentication with secret references | `auth.scram.enabled: true` |
| Admin user | Pre-configured admin with clusterAdmin privileges | `auth.adminUser.*` |
| Additional users | Extra database users with custom role bindings | `users[]` |
| Custom roles | User-defined roles (e.g., CDC/Change Stream for Debezium) | `customRoles[]` |
| TLS encryption | In-transit encryption via cert-manager or manual secrets | `tls.enabled: true` |
| Per-service databases | Isolated MongoDBCommunity instances per microservice | `databases[]` |
| WiredTiger tuning | Journal compressor and commit interval settings | `config.storage.wiredTiger.*` |
| Prometheus monitoring | Metrics via percona/mongodb_exporter sidecar | `monitoring.exporter.enabled: true` |
| ServiceMonitor | Prometheus Operator auto-discovery | `monitoring.serviceMonitor.enabled: true` |
| Pod anti-affinity | Spread members across availability zones | `scheduling.podAntiAffinity.enabled: true` |
| Network policies | Restrict ingress/egress traffic to the replica set | `networkPolicy.enabled: true` |

## Prerequisites

| Requirement | Minimum Version | Notes |
|-------------|----------------|-------|
| Kubernetes | 1.24+ | CRD support required |
| Helm | 3.10+ | OCI registry support recommended |
| MongoDB Community Operator | 0.9+ | Must be installed before deploying this chart |

| Optional Dependency | Purpose |
|---------------------|---------|
| cert-manager | Automated TLS certificate provisioning |
| Prometheus Operator | ServiceMonitor auto-discovery |
| CSI driver / StorageClass | Persistent volume provisioning for data and logs |

## Quick Start

```bash
helm repo add mongodb-operator ./charts/mongodb-operator
helm install my-mongodb ./charts/mongodb-operator -n mongodb --create-namespace
helm status my-mongodb -n mongodb
```

## Examples

| File | Use Case | Features Demonstrated |
|------|----------|----------------------|
| [basic.yaml](examples/basic.yaml) | Simple 3-member replica set | Default SCRAM auth, minimal config |
| [with-cdc-role.yaml](examples/with-cdc-role.yaml) | Custom CDC role for Debezium | `customRoles`, changeStream privileges |
| [multi-database.yaml](examples/multi-database.yaml) | Per-service database isolation | `databases[]` pattern, separate users |
| [production.yaml](examples/production.yaml) | Full production deployment | Monitoring, TLS, anti-affinity, network policy |

## Configuration Reference

### Cluster Metadata

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `cluster.name` | string | `my-mongodb` | Name for the MongoDBCommunity resource |
| `fullnameOverride` | string | `""` | Override the full resource name |

### Image

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `image.repository` | string | `mongo` | MongoDB container image repository |
| `image.tag` | string | `"7.0"` | MongoDB container image tag |

### Replica Set

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `replicaSet.members` | int | `3` | Number of replica set members (1, 3, or 5) |

### Resources

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `resources.mongod.limits.cpu` | string | `"2"` | CPU limit for mongod |
| `resources.mongod.limits.memory` | string | `4Gi` | Memory limit for mongod |
| `resources.mongod.requests.cpu` | string | `500m` | CPU request for mongod |
| `resources.mongod.requests.memory` | string | `2Gi` | Memory request for mongod |
| `resources.agent.limits.cpu` | string | `500m` | CPU limit for the agent sidecar |
| `resources.agent.limits.memory` | string | `512Mi` | Memory limit for the agent sidecar |
| `resources.agent.requests.cpu` | string | `100m` | CPU request for the agent sidecar |
| `resources.agent.requests.memory` | string | `256Mi` | Memory request for the agent sidecar |

### Storage

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `storage.data.size` | string | `50Gi` | Persistent volume size for data |
| `storage.data.storageClass` | string | `""` | StorageClass for data volumes (empty = default) |
| `storage.logs.size` | string | `10Gi` | Persistent volume size for logs |
| `storage.logs.storageClass` | string | `""` | StorageClass for log volumes (empty = default) |

### Authentication

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `auth.scram.enabled` | bool | `true` | Enable SCRAM-SHA-256 authentication |
| `auth.adminUser.name` | string | `admin` | Admin username |
| `auth.adminUser.passwordSecretRef.name` | string | `mongodb-admin-password` | Secret containing the admin password |
| `auth.adminUser.passwordSecretRef.key` | string | `password` | Key within the password Secret |
| `auth.adminUser.database` | string | `admin` | Authentication database for admin |
| `auth.adminUser.roles` | list | clusterAdmin, userAdminAnyDatabase, readWriteAnyDatabase | Admin role bindings |

### Additional Users

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `users` | list | `[]` | Additional MongoDB users |
| `users[].name` | string | -- | Username |
| `users[].database` | string | -- | Authentication database |
| `users[].passwordSecretRef.name` | string | -- | Secret containing the password |
| `users[].passwordSecretRef.key` | string | -- | Key within the password Secret |
| `users[].roles` | list | -- | List of role bindings (`name`, `db`) |

### Custom Roles

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `customRoles` | list | `[]` | Custom MongoDB role definitions |
| `customRoles[].name` | string | -- | Role name |
| `customRoles[].db` | string | -- | Database the role is defined in |
| `customRoles[].privileges` | list | -- | List of privilege objects (resource + actions) |
| `customRoles[].roles` | list | -- | Inherited roles |

### TLS

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `tls.enabled` | bool | `false` | Enable TLS for client and intra-member traffic |
| `tls.certificateSecretRef.name` | string | `""` | Secret containing the TLS certificate |
| `tls.caConfigMapRef.name` | string | `""` | ConfigMap containing the CA certificate |

### MongoDB Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `config.storage.journal.commitIntervalMs` | int | `100` | Journal commit interval in milliseconds |
| `config.storage.wiredTiger.engineConfig.journalCompressor` | string | `zlib` | WiredTiger journal compressor (`zlib`, `snappy`, `none`) |
| `config.extra` | object | `{}` | Arbitrary extra mongod configuration options |

### Monitoring

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `monitoring.serviceMonitor.enabled` | bool | `false` | Create a Prometheus ServiceMonitor |
| `monitoring.serviceMonitor.interval` | string | `30s` | Scrape interval |
| `monitoring.exporter.enabled` | bool | `false` | Deploy mongodb_exporter sidecar |
| `monitoring.exporter.image` | string | `percona/mongodb_exporter:0.40` | Exporter container image |
| `monitoring.exporter.port` | int | `9216` | Exporter metrics port |

### Per-Service Databases

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `databases` | list | `[]` | Additional MongoDBCommunity instances (one per service) |
| `databases[].name` | string | -- | Database instance name |
| `databases[].members` | int | -- | Replica set member count |
| `databases[].storage.data.size` | string | -- | Data volume size |
| `databases[].users` | list | -- | Users scoped to this database instance |

### Scheduling

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `scheduling.nodeSelector` | object | `{}` | Node selector labels |
| `scheduling.tolerations` | list | `[]` | Pod tolerations |
| `scheduling.podAntiAffinity.enabled` | bool | `true` | Enable pod anti-affinity |
| `scheduling.podAntiAffinity.topologyKey` | string | `topology.kubernetes.io/zone` | Topology key for anti-affinity |

### Security Context

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `podSecurityContext.runAsNonRoot` | bool | `true` | Enforce non-root container execution |

### Network Policy

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `networkPolicy.enabled` | bool | `false` | Create a Kubernetes NetworkPolicy |
| `networkPolicy.ingress` | list | `[]` | Ingress rules |
| `networkPolicy.egress` | list | `[]` | Egress rules |

## How-To Guides

### Add a CDC role for Debezium

```yaml
customRoles:
  - name: cdc-role
    db: admin
    privileges:
      - resource:
          db: ""
          collection: ""
        actions:
          - changeStream
          - find
          - listDatabases
          - listCollections
    roles: []

users:
  - name: debezium
    database: admin
    passwordSecretRef:
      name: debezium-password
      key: password
    roles:
      - name: cdc-role
        db: admin
```

### Enable TLS with cert-manager

```yaml
tls:
  enabled: true
  certificateSecretRef:
    name: mongodb-tls-cert
  caConfigMapRef:
    name: mongodb-ca
```

### Set up per-service database isolation

```yaml
databases:
  - name: orders-db
    members: 3
    storage:
      data:
        size: 30Gi
    users:
      - name: orders-svc
        passwordSecretRef:
          name: orders-db-password
          key: password
        roles:
          - name: readWrite
            db: orders-db
```

### Enable Prometheus monitoring

```yaml
monitoring:
  exporter:
    enabled: true
  serviceMonitor:
    enabled: true
    interval: 15s
```

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| MongoDBCommunity CR stuck in `Pending` | Community Operator not installed | Install MongoDB Community Operator >= 0.9 |
| Authentication failures | Password secret missing or wrong key | Verify `passwordSecretRef.name` and `.key` exist in the namespace |
| Replica set members not joining | Pod anti-affinity cannot be satisfied | Check node count vs. `replicaSet.members` or disable anti-affinity |
| PVC stuck in `Pending` | StorageClass not found or no capacity | Verify `storage.data.storageClass` exists and has available volumes |
| Exporter sidecar CrashLoopBackOff | Wrong connection string or auth | Confirm exporter image version and mongod authentication settings |
| TLS handshake errors | Certificate/CA mismatch | Ensure `tls.certificateSecretRef` and `tls.caConfigMapRef` match |
| High memory usage on mongod | WiredTiger cache too large for limit | Increase `resources.mongod.limits.memory` or tune WiredTiger cache |

## Resources Created

| Condition | Resource | API Version |
|-----------|----------|-------------|
| Always | MongoDBCommunity | `mongodbcommunity.mongodb.com/v1` |
| `databases[]` defined | MongoDBCommunity (per database) | `mongodbcommunity.mongodb.com/v1` |
| `monitoring.serviceMonitor.enabled: true` | ServiceMonitor | `monitoring.coreos.com/v1` |
| `networkPolicy.enabled: true` | NetworkPolicy | `networking.k8s.io/v1` |
