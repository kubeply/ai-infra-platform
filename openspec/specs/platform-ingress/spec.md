## ADDED Requirements

### Requirement: Traefik is deployed as a GitOps-managed Helm release

Traefik SHALL be deployed via an ArgoCD `Application` manifest that targets the official Traefik Helm chart. The chart version SHALL be pinned to a specific semver tag (not `latest`) so Renovate can track and propose upgrades. The release SHALL be installed into the `traefik` namespace.

#### Scenario: Traefik Application is synced by ArgoCD

- **WHEN** `clusters/ai-infra-platform/kustomization.yaml` references the networking module
- **THEN** ArgoCD creates a Traefik Application in the `argocd` namespace
- **AND** the Application syncs successfully (no OutOfSync or Degraded state)

#### Scenario: Traefik chart version is pinned

- **WHEN** `platform/networking/traefik/application.yaml` is inspected
- **THEN** `spec.source.targetRevision` is a pinned semantic version (e.g., `32.x.y`)
- **AND** it does NOT contain `latest` or a version range

#### Scenario: Renovate detects Traefik chart version

- **WHEN** Renovate scans `platform/networking/traefik/application.yaml`
- **THEN** it identifies the pinned Helm chart version
- **AND** opens a PR when a newer chart version is available

### Requirement: k3s built-in Traefik is disabled

The k3s provisioning module SHALL pass `--disable=traefik` during k3s installation so that the default unmanaged Traefik instance does not conflict with the GitOps-managed release.

#### Scenario: k3s install command disables built-in Traefik

- **WHEN** `terraform/modules/hetzner-k3s/` provisions a new cluster
- **THEN** the k3s install command includes `--disable=traefik`
- **AND** no default Traefik HelmChart CRD resource is created by k3s

### Requirement: Traefik exposes HTTP and HTTPS on the node's public IP

On a single-node k3s cluster, Traefik SHALL use `hostPort` mode to listen on ports 80 (HTTP) and 443 (HTTPS) of the node's public IP address. A LoadBalancer service type SHALL NOT be required.

#### Scenario: HTTP traffic is routed through Traefik

- **WHEN** an HTTP request is sent to port 80 of the cluster node's IP
- **THEN** Traefik receives the request and can route it to a backend service

#### Scenario: HTTPS traffic is routed through Traefik

- **WHEN** an HTTPS request is sent to port 443 of the cluster node's IP
- **THEN** Traefik receives and terminates the TLS connection, routing plaintext to the backend

### Requirement: Traefik deployment is verified by verify-platform.sh

`script/verify-platform.sh` SHALL include a check that the Traefik deployment is running and ready in the `traefik` namespace.

#### Scenario: verify-platform.sh passes with Traefik running

- **WHEN** `script/verify-platform.sh` is executed on a cluster with the networking module active
- **THEN** it checks that the `traefik` Deployment in namespace `traefik` has at least 1 ready replica
- **AND** the script exits 0 if the check passes
- **AND** the script exits non-zero and prints an error if Traefik is not ready

### Requirement: Platform networking module follows opt-in Kustomize structure

The `platform/networking/` directory SHALL expose a top-level `kustomization.yaml` that clusters reference. Adding `../../platform/networking` to a cluster's kustomization resources SHALL be the only step needed to activate the networking module.

#### Scenario: Opt-in from ai-infra-platform cluster

- **WHEN** `../../platform/networking` is added to `clusters/ai-infra-platform/kustomization.yaml` resources
- **THEN** `kubectl kustomize clusters/ai-infra-platform/` includes the Traefik and cert-manager Application manifests
- **AND** no additional changes to cluster files are required
