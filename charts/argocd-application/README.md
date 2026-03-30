# ArgoCD Application Chart

Helm chart for managing ArgoCD Applications, AppProjects, and Namespaces declaratively. Supports Helm, Kustomize, directory, and multi-source patterns with full sync policy control including auto-prune, self-heal, retry backoff, and sync-wave ordering for complex deployment pipelines.

## Architecture

```
                    ┌──────────────────────────────┐
                    │      ArgoCD Namespace         │
                    │                              │
                    │  ┌────────────────────────┐  │
                    │  │  AppProject            │  │
                    │  │  - destinations        │  │
                    │  │  - sourceRepos         │  │
                    │  │  - clusterResources    │  │
                    │  │  - RBAC roles          │  │
                    │  └────────┬───────────────┘  │
                    │           │                  │
                    │  ┌───────▼────────────────┐  │
                    │  │  Application(s)         │  │
                    │  │  ┌──────────────────┐  │  │
                    │  │  │ Source (Git/Helm) │  │  │
                    │  │  └──────────────────┘  │  │
                    │  │  ┌──────────────────┐  │  │
                    │  │  │ SyncPolicy       │  │  │
                    │  │  │ - auto prune     │  │  │
                    │  │  │ - self-heal      │  │  │
                    │  │  │ - retry backoff  │  │  │
                    │  │  └──────────────────┘  │  │
                    │  │  ┌──────────────────┐  │  │
                    │  │  │ Destination      │  │  │
                    │  │  │ (cluster + ns)   │  │  │
                    │  │  └──────────────────┘  │  │
                    │  └────────────────────────┘  │
                    │                              │
                    │  ┌────────────────────────┐  │
                    │  │  Namespace(s)           │  │
                    │  │  (optional pre-create)  │  │
                    │  └────────────────────────┘  │
                    └──────────────────────────────┘
```

## Features

| Feature | Description | Enabled by |
|---------|-------------|-----------|
| AppProject | RBAC, destination and source repo restrictions | `project.enabled` |
| Application | Deploy apps from Git, Helm repos, or Kustomize | `applications` list |
| Multi-Source | Combine chart repo + Git values repo in one Application | `sourceType: multi` |
| Helm Source | Helm chart with release name, value files, parameters | `sourceType: helm` |
| Kustomize Source | Kustomize overlay deployment | `sourceType: kustomize` |
| Directory Source | Plain manifest directory | `sourceType: directory` |
| Auto Sync | Automatic prune and self-heal on drift | `syncPolicy.automated` |
| Retry Backoff | Exponential retry on sync failure | `syncPolicy.retry` |
| Sync Options | CreateNamespace, PruneLast, ServerSideApply | `syncPolicy.syncOptions` |
| Ignore Differences | Suppress drift detection for controller-managed fields | `ignoreDifferences` |
| Sync Waves | Ordered deployment via annotations | `annotations` |
| Namespaces | Pre-create namespaces with labels and annotations | `namespaces` list |

## Prerequisites

- Kubernetes 1.26+
- Helm 3.12+
- [ArgoCD](https://argoproj.github.io/cd/) installed in the cluster

### Optional dependencies

| Feature | Requires |
|---------|----------|
| Multi-source Applications | ArgoCD 2.6+ |
| ServerSideApply sync option | ArgoCD 2.5+ |
| Istio-injected namespaces | Istio service mesh installed |

## Quick Start

```bash
# Deploy a single application
helm install my-app ./charts/argocd-application \
  --set project.name=my-project \
  --set applications[0].name=my-app

# With a values file
helm install my-apps ./charts/argocd-application -f my-values.yaml

# Dry run to inspect output
helm template my-apps ./charts/argocd-application -f my-values.yaml
```

## Examples

| File | Use Case | Features Demonstrated |
|------|----------|----------------------|
| [single-app.yaml](examples/single-app.yaml) | Simple Helm application | Single source, auto-sync, basic project |
| [multi-source.yaml](examples/multi-source.yaml) | External chart + Git values | Multi-source pattern, ref-based values |
| [gitops-3-repo.yaml](examples/gitops-3-repo.yaml) | 3-repo GitOps pattern | Multiple apps, separate config repos |
| [sync-waves.yaml](examples/sync-waves.yaml) | Ordered deployment | Sync-wave annotations, namespace pre-creation |
| [kustomize-app.yaml](examples/kustomize-app.yaml) | Kustomize application | Kustomize source type, overlays |

## Configuration Reference

### Global

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `nameOverride` | string | `""` | Override chart name |
| `fullnameOverride` | string | `""` | Override full release name |
| `argocdNamespace` | string | `argocd` | Namespace where ArgoCD CRDs live |

### Project

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `project.enabled` | bool | `true` | Create an AppProject |
| `project.name` | string | `my-project` | Project name |
| `project.description` | string | `My application project` | Project description |
| `project.destinations` | list | see values.yaml | Allowed destination clusters and namespaces |
| `project.destinations[].namespace` | string | `*` | Allowed namespace (wildcard supported) |
| `project.destinations[].server` | string | `https://kubernetes.default.svc` | Allowed cluster API server |
| `project.sourceRepos` | list | `[*]` | Allowed source repository URLs |
| `project.clusterResourceWhitelist` | list | `[{group: *, kind: *}]` | Allowed cluster-scoped resources |
| `project.namespaceResourceBlacklist` | list | `[]` | Denied namespace-scoped resources |
| `project.roles` | list | `[]` | RBAC roles for CI/CD and teams |
| `project.roles[].name` | string | - | Role name |
| `project.roles[].description` | string | - | Role description |
| `project.roles[].policies` | list | - | Casbin policy strings |
| `project.roles[].groups` | list | - | Groups bound to this role |

### Applications

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `applications` | list | see values.yaml | List of ArgoCD Applications to create |
| `applications[].name` | string | `my-app` | Application name |
| `applications[].sourceType` | string | `helm` | Source type: `helm`, `directory`, `kustomize`, or `multi` |
| `applications[].project` | string | `my-project` | Project reference |
| `applications[].annotations` | map | `{}` | Annotations (e.g., sync-wave ordering) |

### Application Destination

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `applications[].destination.namespace` | string | `default` | Target namespace |
| `applications[].destination.server` | string | `https://kubernetes.default.svc` | Target cluster API server |

### Application Source (Single)

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `applications[].source.repoURL` | string | - | Git or Helm repository URL |
| `applications[].source.targetRevision` | string | `HEAD` | Branch, tag, or commit SHA |
| `applications[].source.path` | string | - | Path within the repository |
| `applications[].source.helm.releaseName` | string | - | Helm release name |
| `applications[].source.helm.valueFiles` | list | `[values.yaml]` | Helm value files |
| `applications[].source.helm.parameters` | list | - | Helm `--set` overrides |

### Application Sources (Multi)

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `applications[].sources` | list | `[]` | List of sources (when sourceType: multi) |
| `applications[].sources[].repoURL` | string | - | Repository URL |
| `applications[].sources[].chart` | string | - | Helm chart name (for Helm repos) |
| `applications[].sources[].targetRevision` | string | - | Revision |
| `applications[].sources[].ref` | string | - | Reference name for cross-source value files |
| `applications[].sources[].helm` | map | - | Helm-specific settings |

### Application Sync Policy

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `applications[].syncPolicy.automated.prune` | bool | `true` | Delete resources removed from Git |
| `applications[].syncPolicy.automated.selfHeal` | bool | `true` | Revert manual changes in cluster |
| `applications[].syncPolicy.syncOptions` | list | see values.yaml | Sync options (CreateNamespace, PruneLast, ServerSideApply) |
| `applications[].syncPolicy.retry.limit` | int | `5` | Max sync retry attempts |
| `applications[].syncPolicy.retry.backoff.duration` | string | `5s` | Initial retry delay |
| `applications[].syncPolicy.retry.backoff.factor` | int | `2` | Backoff multiplier |
| `applications[].syncPolicy.retry.backoff.maxDuration` | string | `3m` | Maximum retry delay |

### Application Ignore Differences

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `applications[].ignoreDifferences` | list | `[]` | Fields to ignore during drift detection |
| `applications[].ignoreDifferences[].group` | string | - | API group |
| `applications[].ignoreDifferences[].kind` | string | - | Resource kind |
| `applications[].ignoreDifferences[].jsonPointers` | list | - | JSON pointers to ignore |

### Namespaces

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `namespaces` | list | `[]` | Namespaces to pre-create |
| `namespaces[].name` | string | - | Namespace name |
| `namespaces[].labels` | map | - | Namespace labels (e.g., `istio-injection: enabled`) |
| `namespaces[].annotations` | map | - | Namespace annotations |

## How-To Guides

### Deploy a Helm chart from a Git repository

```yaml
project:
  enabled: true
  name: my-team

applications:
  - name: my-api
    sourceType: helm
    destination:
      namespace: production
      server: "https://kubernetes.default.svc"
    project: my-team
    source:
      repoURL: "https://github.com/my-org/my-repo.git"
      targetRevision: main
      path: "charts/my-api"
      helm:
        releaseName: my-api
        valueFiles:
          - values-production.yaml
    syncPolicy:
      automated:
        prune: true
        selfHeal: true
```

### Use multi-source to separate chart and values repos

```yaml
applications:
  - name: my-service
    sourceType: multi
    project: my-team
    destination:
      namespace: production
    sources:
      - repoURL: "https://charts.example.com"
        chart: my-chart
        targetRevision: "2.0.0"
        helm:
          releaseName: my-service
          valueFiles:
            - "$values/envs/production/values.yaml"
      - repoURL: "https://github.com/my-org/my-values.git"
        targetRevision: main
        ref: values
```

### Order deployments with sync-waves

```yaml
namespaces:
  - name: my-namespace
    labels:
      istio-injection: enabled

applications:
  - name: database
    annotations:
      argocd.argoproj.io/sync-wave: "1"
    # ...
  - name: backend
    annotations:
      argocd.argoproj.io/sync-wave: "2"
    # ...
  - name: frontend
    annotations:
      argocd.argoproj.io/sync-wave: "3"
    # ...
```

### Ignore HPA-managed replica count

```yaml
applications:
  - name: my-api
    ignoreDifferences:
      - group: apps
        kind: Deployment
        jsonPointers:
          - /spec/replicas
```

### Add CI/CD RBAC roles to a project

```yaml
project:
  enabled: true
  name: my-team
  roles:
    - name: ci-role
      description: "CI/CD sync permissions"
      policies:
        - "p, proj:my-team:ci-role, applications, sync, my-team/*, allow"
        - "p, proj:my-team:ci-role, applications, get, my-team/*, allow"
      groups:
        - my-ci-group
```

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Application stuck in `Unknown` | ArgoCD cannot reach the source repo | Verify `source.repoURL` is accessible and repo credentials are configured in ArgoCD |
| Sync fails with `permission denied` | Project restrictions too narrow | Add the destination namespace/cluster to `project.destinations` and the repo to `project.sourceRepos` |
| Resources pruned unexpectedly | `automated.prune: true` removing manually created resources | Add resources to source control or disable auto-prune |
| Sync-wave ordering ignored | Missing annotation prefix | Ensure annotation is exactly `argocd.argoproj.io/sync-wave` with a string value |
| Drift detected on controller-managed fields | HPA or other controllers modify spec | Add fields to `ignoreDifferences` with `jsonPointers` |
| Application not appearing in ArgoCD UI | Created in wrong namespace | Verify `argocdNamespace` matches your ArgoCD installation namespace |
| Multi-source `$ref` not resolving | ArgoCD version too old | Upgrade to ArgoCD 2.6+ for multi-source support |

## Resources Created

| Condition | Resource | API Version |
|-----------|----------|-------------|
| `project.enabled` | AppProject | `argoproj.io/v1alpha1` |
| Per `applications[]` entry | Application | `argoproj.io/v1alpha1` |
| Per `namespaces[]` entry | Namespace | `v1` |
