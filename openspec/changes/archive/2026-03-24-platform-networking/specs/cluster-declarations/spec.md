## MODIFIED Requirements

### Requirement: Dev cluster activates only the gitops module at Layer 2

The `clusters/ai-infra-platform/kustomization.yaml` SHALL reference only the ArgoCD (gitops) module at Layer 2 completion. It SHALL NOT reference any Layer 3 platform modules (networking, observability, storage, AI tooling). Layer 3 modules are added to `clusters/ai-infra-platform/` as part of their own implementation changes.

#### Scenario: Dev cluster resources at Layer 2 completion

- **WHEN** the `clusters/ai-infra-platform/` directory is inspected after Layer 2 is implemented
- **THEN** it contains an ArgoCD Application pointing to the gitops platform module (or a self-referential ArgoCD configuration)
- **AND** it does NOT contain references to networking, observability, storage, or AI modules

## ADDED Requirements

### Requirement: Dev cluster opts into the networking module at Layer 3

After the platform-networking module is implemented, `clusters/ai-infra-platform/kustomization.yaml` SHALL add `../../platform/networking` to its resources list. This activates Traefik and cert-manager via ArgoCD on the dev cluster.

#### Scenario: Dev cluster resources after platform-networking is activated

- **WHEN** `clusters/ai-infra-platform/kustomization.yaml` is inspected after the platform-networking change is applied
- **THEN** its `resources` list includes a reference to `../../platform/networking`
- **AND** `kubectl kustomize clusters/ai-infra-platform/` produces manifests that include the Traefik and cert-manager ArgoCD Application resources

#### Scenario: Dev cluster kustomize output remains valid

- **WHEN** `kubectl kustomize clusters/ai-infra-platform/` is executed after the networking module is added
- **THEN** it produces valid Kubernetes manifest YAML with no errors
