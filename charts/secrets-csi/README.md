# Secrets CSI

Cloud-agnostic Helm chart for the Secrets Store CSI Driver that mounts secrets from external providers -- AWS Secrets Manager, Azure Key Vault, GCP Secret Manager, or HashiCorp Vault -- directly into Kubernetes pods as volume mounts. It creates a SecretProviderClass with provider-specific configuration, an optional ServiceAccount with workload identity annotations, and can optionally sync secrets as native Kubernetes Secrets.

## Architecture

```
  ┌──────────────────────────────────────────────────────┐
  │  Kubernetes Cluster                                  │
  │                                                      │
  │  ┌──────────────┐      ┌─────────────────────────┐  │
  │  │ ServiceAccount│─────>│ SecretProviderClass      │  │
  │  │ (IRSA / WI)  │      │ (provider: aws|azure|   │  │
  │  └──────────────┘      │  gcp|vault)              │  │
  │                         └────────────┬────────────┘  │
  │                                      │ CSI mount     │
  │  ┌───────────────────────────────────▼────────────┐  │
  │  │  Application Pod                               │  │
  │  │  /mnt/secrets/DB_USER                          │  │
  │  │  /mnt/secrets/DB_PASS                          │  │
  │  └────────────────────────────────────────────────┘  │
  │                                      |               │
  │                         ┌────────────▼────────────┐  │
  │                         │ Kubernetes Secret (opt.) │  │
  │                         │ (syncAsKubernetesSecret) │  │
  │                         └─────────────────────────┘  │
  └──────────────────────────────────────────────────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
     ┌────────▼───┐  ┌──────▼─────┐  ┌────▼────────┐
     │ AWS Secrets │  │ Azure Key  │  │ GCP Secret  │
     │ Manager     │  │ Vault      │  │ Manager     │
     └─────────────┘  └────────────┘  └─────────────┘
                             │
                      ┌──────▼─────┐
                      │ HashiCorp  │
                      │ Vault      │
                      └────────────┘
```

## Features

| Feature | Description | Enabled by |
|---------|-------------|------------|
| AWS Secrets Manager | Mount secrets via IRSA with optional JMESPath key extraction | `provider: aws` |
| Azure Key Vault | Mount secrets, keys, or certificates via Workload / Pod Identity | `provider: azure` |
| GCP Secret Manager | Mount secrets via GCP Workload Identity | `provider: gcp` |
| HashiCorp Vault | Mount secrets via Kubernetes, JWT, or AppRole auth | `provider: vault` |
| Kubernetes Secret sync | Optionally replicate CSI-mounted secrets as K8s Secrets in etcd | `*.syncAsKubernetesSecret.enabled` |
| ServiceAccount creation | Create a ServiceAccount with cloud identity annotations | `serviceAccount.create` |
| JMESPath extraction | Extract individual keys from composite AWS secrets | `aws.secrets[].keys[].jmesPath` |

## Prerequisites

| Requirement | Minimum Version | Notes |
|-------------|-----------------|-------|
| Kubernetes | 1.24+ | |
| Helm | 3.10+ | |
| Secrets Store CSI Driver | 1.3+ | [Installation guide](https://secrets-store-csi-driver.sigs.k8s.io/getting-started/installation) |
| Provider CSI driver | -- | aws-provider, azure-provider, gcp-provider, or vault-provider |

## Quick Start

```bash
helm repo add my-charts https://charts.example.com
helm repo update
helm install secrets my-charts/secrets-csi -n my-app --set provider=aws
```

## Examples

| File | Use Case | Features Demonstrated |
|------|----------|----------------------|
| [aws-secrets-manager.yaml](examples/aws-secrets-manager.yaml) | AWS with IRSA | IRSA annotations, JMESPath extraction, K8s sync |
| [azure-key-vault.yaml](examples/azure-key-vault.yaml) | Azure Key Vault | Workload Identity, secret/key/cert types |
| [gcp-secret-manager.yaml](examples/gcp-secret-manager.yaml) | GCP Secret Manager | Workload Identity, version pinning |
| [hashicorp-vault.yaml](examples/hashicorp-vault.yaml) | HashiCorp Vault | Kubernetes auth, secret path, enterprise namespace |

## Configuration Reference

### General

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `nameOverride` | string | `""` | Override the chart name |
| `fullnameOverride` | string | `""` | Override the full release name |
| `provider` | string | `aws` | Cloud provider: `aws`, `azure`, `gcp`, or `vault` |

### Service Account

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `serviceAccount.create` | bool | `true` | Create a ServiceAccount |
| `serviceAccount.name` | string | `""` | Override ServiceAccount name (defaults to release fullname) |
| `serviceAccount.annotations` | object | `{}` | Annotations (e.g. IRSA role ARN, GCP SA, Azure client ID) |

### AWS Secrets Manager

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `aws.secrets` | list | (see values.yaml) | List of AWS secrets to mount |
| `aws.secrets[].name` | string | `my-app-secrets` | Logical name for the secret |
| `aws.secrets[].secretArn` | string | `""` | Full ARN of the AWS Secrets Manager secret |
| `aws.secrets[].keys` | list | `[]` | Individual key extraction entries |
| `aws.secrets[].keys[].objectName` | string | -- | Object name for the full secret blob |
| `aws.secrets[].keys[].objectAlias` | string | -- | Alias for the mounted file |
| `aws.secrets[].keys[].jmesPath` | list | -- | JMESPath expressions for sub-key extraction |
| `aws.secrets[].keys[].jmesPath[].path` | string | -- | JMESPath expression |
| `aws.secrets[].keys[].jmesPath[].objectAlias` | string | -- | Alias for the extracted key |
| `aws.syncAsKubernetesSecret.enabled` | bool | `false` | Sync as a native Kubernetes Secret |
| `aws.syncAsKubernetesSecret.secretName` | string | `my-k8s-secret` | Name for the synced K8s Secret |
| `aws.syncAsKubernetesSecret.type` | string | `Opaque` | Kubernetes Secret type |
| `aws.syncAsKubernetesSecret.data` | list | `[]` | Mapping of objectName to Secret key |

### Azure Key Vault

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `azure.keyvaultName` | string | `""` | Name of the Azure Key Vault |
| `azure.tenantId` | string | `""` | Azure AD tenant ID |
| `azure.usePodIdentity` | bool | `false` | Use AAD Pod Identity |
| `azure.useVMManagedIdentity` | bool | `false` | Use VM Managed Identity |
| `azure.userAssignedIdentityID` | string | `""` | User-assigned managed identity client ID |
| `azure.secrets` | list | (see values.yaml) | List of Azure secrets to mount |
| `azure.secrets[].name` | string | `my-secret` | Logical name |
| `azure.secrets[].objectName` | string | -- | Name of the object in Key Vault |
| `azure.secrets[].objectType` | string | `secret` | Type: `secret`, `key`, or `cert` |
| `azure.secrets[].objectVersion` | string | `""` | Pin to a specific version (empty = latest) |
| `azure.syncAsKubernetesSecret.enabled` | bool | `false` | Sync as a native Kubernetes Secret |
| `azure.syncAsKubernetesSecret.secretName` | string | `""` | Name for the synced K8s Secret |
| `azure.syncAsKubernetesSecret.type` | string | `Opaque` | Kubernetes Secret type |
| `azure.syncAsKubernetesSecret.data` | list | `[]` | Mapping of objectName to Secret key |

### GCP Secret Manager

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `gcp.projectId` | string | `""` | GCP project ID |
| `gcp.secrets` | list | (see values.yaml) | List of GCP secrets to mount |
| `gcp.secrets[].resourceName` | string | -- | Full resource path including version |
| `gcp.secrets[].objectName` | string | -- | Alias for the mounted file |
| `gcp.syncAsKubernetesSecret.enabled` | bool | `false` | Sync as a native Kubernetes Secret |
| `gcp.syncAsKubernetesSecret.secretName` | string | `""` | Name for the synced K8s Secret |
| `gcp.syncAsKubernetesSecret.type` | string | `Opaque` | Kubernetes Secret type |
| `gcp.syncAsKubernetesSecret.data` | list | `[]` | Mapping of objectName to Secret key |

### HashiCorp Vault

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `vault.address` | string | `""` | Vault server address |
| `vault.roleName` | string | `""` | Vault role for authentication |
| `vault.authMethod` | string | `kubernetes` | Auth method: `kubernetes`, `jwt`, or `approle` |
| `vault.namespace` | string | `""` | Vault namespace (enterprise feature) |
| `vault.secrets` | list | (see values.yaml) | List of Vault secrets to mount |
| `vault.secrets[].secretPath` | string | -- | Vault secret path |
| `vault.secrets[].objectName` | string | -- | Alias for the mounted file |
| `vault.secrets[].secretKey` | string | -- | Key within the Vault secret |
| `vault.syncAsKubernetesSecret.enabled` | bool | `false` | Sync as a native Kubernetes Secret |
| `vault.syncAsKubernetesSecret.secretName` | string | `""` | Name for the synced K8s Secret |
| `vault.syncAsKubernetesSecret.type` | string | `Opaque` | Kubernetes Secret type |
| `vault.syncAsKubernetesSecret.data` | list | `[]` | Mapping of objectName to Secret key |

### Volume Mount

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `volumeMount.name` | string | `secrets-store` | Volume name used in pod spec |
| `volumeMount.mountPath` | string | `/mnt/secrets` | Mount path inside the container |
| `volumeMount.readOnly` | bool | `true` | Mount as read-only |

## How-To Guides

### Mount an AWS secret with JMESPath extraction

```yaml
provider: aws
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/my-role
aws:
  secrets:
    - name: db-creds
      secretArn: arn:aws:secretsmanager:us-east-1:123456789012:secret:prod/db
      keys:
        - objectName: full-secret
          objectAlias: DB_SECRET
          jmesPath:
            - path: username
              objectAlias: DB_USER
            - path: password
              objectAlias: DB_PASS
```

### Sync a Vault secret as a Kubernetes Secret for envFrom usage

```yaml
provider: vault
vault:
  address: https://vault.example.com
  roleName: my-app
  secrets:
    - secretPath: secret/data/my-app
      objectName: api-key
      secretKey: key
  syncAsKubernetesSecret:
    enabled: true
    secretName: my-app-env
    type: Opaque
    data:
      - objectName: api-key
        key: API_KEY
```

### Use Azure Key Vault with VM Managed Identity

```yaml
provider: azure
azure:
  keyvaultName: my-keyvault
  tenantId: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  useVMManagedIdentity: true
  userAssignedIdentityID: "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy"
  secrets:
    - name: tls-cert
      objectName: my-tls-cert
      objectType: cert
```

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| Pod stuck in `ContainerCreating` | CSI driver or provider not installed | Install the Secrets Store CSI Driver and the matching provider |
| `FailedMount` with permission denied | ServiceAccount missing identity annotation | Add the correct IRSA / Workload Identity annotation |
| Secret file is empty at mount path | Incorrect `secretArn`, `objectName`, or `secretPath` | Verify the secret exists in the provider console/CLI |
| `SecretProviderClass not found` | Wrong namespace or chart not installed | Ensure the chart is installed in the same namespace as the pod |
| Synced K8s Secret not created | `syncAsKubernetesSecret.enabled` is false or CSI sync feature is off | Enable the flag and set `--set syncSecret.enabled=true` on the CSI driver |
| JMESPath extraction returns null | Path expression does not match the JSON structure | Test with `aws secretsmanager get-secret-value` and validate the path |

## Resources Created

| Condition | Resource | API Version |
|-----------|----------|-------------|
| Always | SecretProviderClass | secrets-store.csi.x-k8s.io/v1 |
| `serviceAccount.create` | ServiceAccount | v1 |
| `*.syncAsKubernetesSecret.enabled` | Secret (synced by CSI driver) | v1 |
