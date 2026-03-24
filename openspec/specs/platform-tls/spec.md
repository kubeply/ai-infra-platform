## ADDED Requirements

### Requirement: cert-manager is deployed as a GitOps-managed Helm release

cert-manager SHALL be deployed via an ArgoCD `Application` manifest targeting the official cert-manager Helm chart (`cert-manager` chart from `charts.jetstack.io`). The chart version SHALL be pinned to a specific semver tag. The release SHALL be installed into the `cert-manager` namespace with CRDs installed via the `installCRDs: true` Helm value.

#### Scenario: cert-manager Application is synced by ArgoCD

- **WHEN** `clusters/ai-infra-platform/kustomization.yaml` references the networking module
- **THEN** ArgoCD creates a cert-manager Application in the `argocd` namespace
- **AND** the Application syncs successfully
- **AND** the `cert-manager`, `cert-manager-webhook`, and `cert-manager-cainjector` Deployments are ready in the `cert-manager` namespace

### Requirement: ClusterIssuer resources are applied after cert-manager CRDs exist

The `ClusterIssuer` resources SHALL be deployed by a separate ArgoCD `Application` that points to a repo path containing only issuer manifests. This issuer Application SHALL sync after the cert-manager Helm Application so the cert-manager CRDs exist before ArgoCD applies any `ClusterIssuer` resources.

#### Scenario: Issuer Application is ordered after cert-manager

- **WHEN** `platform/networking/cert-manager/issuers-application.yaml` is inspected
- **THEN** it points to `platform/networking/cert-manager/issuers`
- **AND** it is configured to sync after `platform/networking/cert-manager/application.yaml`
- **AND** the parent `platform/networking/cert-manager/kustomization.yaml` does NOT list raw `ClusterIssuer` resources directly

#### Scenario: cert-manager chart version is pinned

- **WHEN** `platform/networking/cert-manager/application.yaml` is inspected
- **THEN** `spec.source.targetRevision` is a pinned semantic version (e.g., `v1.x.y`)
- **AND** it does NOT contain `latest` or a version range

#### Scenario: Renovate detects cert-manager chart version

- **WHEN** Renovate scans `platform/networking/cert-manager/application.yaml`
- **THEN** it identifies the pinned Helm chart version
- **AND** opens a PR when a newer chart version is available

### Requirement: A Let's Encrypt staging ClusterIssuer is deployed

A `ClusterIssuer` resource named `letsencrypt-staging` SHALL be deployed alongside cert-manager. It SHALL use the ACME HTTP-01 challenge solver and target the Let's Encrypt staging endpoint (`https://acme-staging-v02.api.letsencrypt.org/directory`). This issuer is used by CI and non-production workloads to avoid Let's Encrypt production rate limits.

#### Scenario: Staging ClusterIssuer is created

- **WHEN** the networking module is synced by ArgoCD
- **THEN** a `ClusterIssuer` named `letsencrypt-staging` exists in the cluster
- **AND** its status condition `Ready` is `True`

#### Scenario: Staging ClusterIssuer uses HTTP-01 solver

- **WHEN** `platform/networking/cert-manager/issuers/cluster-issuer.yaml` is inspected
- **THEN** `spec.acme.server` points to the Let's Encrypt staging URL
- **AND** `spec.acme.solvers[].http01.ingress.class` is set to `traefik`

### Requirement: A Let's Encrypt production ClusterIssuer is deployed

A `ClusterIssuer` resource named `letsencrypt-prod` SHALL be deployed alongside cert-manager. It SHALL use the ACME HTTP-01 challenge solver and target the Let's Encrypt production endpoint. This issuer is used by production workloads that require publicly trusted certificates.

#### Scenario: Production ClusterIssuer is created

- **WHEN** the networking module is synced by ArgoCD
- **THEN** a `ClusterIssuer` named `letsencrypt-prod` exists in the cluster
- **AND** its status condition `Ready` is `True`

#### Scenario: Production ClusterIssuer uses HTTP-01 solver

- **WHEN** `platform/networking/cert-manager/issuers/cluster-issuer.yaml` is inspected
- **THEN** `spec.acme.server` points to the Let's Encrypt production URL (`https://acme-v02.api.letsencrypt.org/directory`)
- **AND** `spec.acme.solvers[].http01.ingress.class` is set to `traefik`

### Requirement: ACME account email is a documented literal value

The ACME registration email address SHALL be set as a literal string in each `ClusterIssuer` manifest because cert-manager does not support sourcing `spec.acme.email` from a Secret reference. The reference repo SHALL use a clearly documented placeholder email value and note that operators must replace it before requesting production certificates.

#### Scenario: ClusterIssuer contains a documented placeholder email

- **WHEN** `platform/networking/cert-manager/issuers/cluster-issuer.yaml` is inspected
- **THEN** `spec.acme.email` is a non-empty literal string
- **AND** an inline comment documents that the placeholder must be replaced before production use

### Requirement: cert-manager deployment is verified by verify-platform.sh

`script/verify-platform.sh` SHALL include a check that the cert-manager Deployment and its companion Deployments (`cert-manager-webhook`, `cert-manager-cainjector`) are running and ready in the `cert-manager` namespace.

#### Scenario: verify-platform.sh passes with cert-manager running

- **WHEN** `script/verify-platform.sh` is executed on a cluster with the networking module active
- **THEN** it checks that `cert-manager`, `cert-manager-webhook`, and `cert-manager-cainjector` Deployments each have at least 1 ready replica in the `cert-manager` namespace
- **AND** the script exits 0 if all checks pass
- **AND** the script exits non-zero and prints an error message identifying the failing component if any check fails
