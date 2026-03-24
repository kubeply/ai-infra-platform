## Context

Layer 2 ends with a cluster that has ArgoCD running and self-managing via a root Application pointing at `clusters/ai-infra-platform/`. The cluster has no ingress, no TLS, and no way to expose services externally. k3s ships Traefik as a default add-on, but it is installed outside of GitOps control — unversioned, untracked, and not pinned.

The networking module is the first addition to `platform/`. It must establish the `platform/` directory structure that all future modules follow, and it must deliver two working capabilities: managed ingress (Traefik) and automatic TLS (cert-manager).

## Goals / Non-Goals

**Goals:**
- Establish the `platform/<module>/` directory structure and Kustomize conventions for opt-in modules.
- Replace the unmanaged k3s Traefik add-on with a GitOps-managed, pinned Helm release.
- Deploy cert-manager with a ClusterIssuer for Let's Encrypt (staging and production).
- Update `clusters/ai-infra-platform/` to opt into the networking module.
- Extend `script/verify-platform.sh` to verify Traefik and cert-manager health.

**Non-Goals:**
- DNS management (handled by the shared Terraform dns module in Layer 1).
- Wildcard certificate provisioning (HTTP-01 challenge only for now; DNS-01 is a future enhancement).
- Ingress objects for specific apps (Layer 4 concern).
- Multi-cluster networking or service mesh (future module).

## Decisions

### D1: Traefik over ingress-nginx

k3s bundles Traefik by default. Managing it via GitOps means aligning with what k3s operators already expect, reducing cognitive overhead for anyone running the smoke-test cluster. Switching to ingress-nginx would introduce friction without a clear benefit at this stage.

**Alternative considered:** ingress-nginx — more common in production setups and better documented for cert-manager integration, but requires disabling the k3s default Traefik add-on explicitly via a k3s install flag, which complicates the bootstrap script.

### D2: Disable k3s built-in Traefik, install via Helm through ArgoCD

k3s's built-in Traefik is a HelmChart CRD resource installed by the k3s agent. To avoid conflicts, the provisioning module must pass `--disable=traefik` during k3s install. The GitOps-managed Traefik Helm release then takes over.

**Impact:** `terraform/modules/hetzner-k3s/` will need to add `--disable=traefik` to the k3s install command. This is a one-line Terraform change.

**Alternative considered:** Keep k3s Traefik and patch it via GitOps — not feasible because k3s re-installs it on upgrades, creating a conflict with the ArgoCD-managed release.

### D3: ArgoCD Application per component (not one umbrella Application)

Each platform sub-component (Traefik, cert-manager) gets its own ArgoCD Application manifest. This matches the existing pattern in `clusters/ai-infra-platform/` (argocd.yaml, sealed-secrets.yaml are each separate manifests) and makes it easy to disable a single component without touching others.

### D4: Module structure — `platform/<module>/` with a top-level `kustomization.yaml`

```
platform/
  networking/
    kustomization.yaml       ← entry point referenced by clusters/
    traefik/
      kustomization.yaml
      application.yaml       ← ArgoCD Application for Traefik Helm release
    cert-manager/
      kustomization.yaml
      application.yaml       ← ArgoCD Application for cert-manager Helm release
      issuers-application.yaml
      issuers/
        kustomization.yaml
        cluster-issuer.yaml  ← ClusterIssuer resources for Let's Encrypt
```

`clusters/ai-infra-platform/kustomization.yaml` adds `../../platform/networking` to its resources list.

### D5: Let's Encrypt HTTP-01 challenge only (for now)

HTTP-01 requires no DNS API credentials — just a reachable port 80. Since the dev cluster has a public IP (Hetzner CX22), this works without extra secrets. DNS-01 (for wildcard certs) is deferred to a future enhancement that would integrate with the shared Terraform dns module.

### D6: Deploy ClusterIssuers via a second child Application

The `ClusterIssuer` resources should not live as raw manifests beside the cert-manager Helm `Application` in the root cluster kustomization. The CRDs are installed by the cert-manager Helm chart, so applying a `ClusterIssuer` before that chart is healthy would fail.

Instead, cert-manager keeps two child Applications:
- `application.yaml` installs the Jetstack Helm chart.
- `issuers-application.yaml` points to a repo path (`platform/networking/cert-manager/issuers/`) containing the `ClusterIssuer` manifests and syncs in a later wave than the Helm Application.

This preserves the app-of-apps pattern and gives ArgoCD a clean dependency boundary.

## Risks / Trade-offs

- **k3s Traefik disable flag**: The `--disable=traefik` flag must be passed at k3s install time. Existing clusters created without it will have a conflicting Traefik. Mitigation: smoke-test always provisions a fresh cluster, so CI is safe. Document in the runbook that existing clusters need Traefik disabled before opting in.
- **Helm chart versions**: Traefik and cert-manager charts must be pinned (not `latest`) so Renovate can track them. If a chart version is incompatible with the running k3s version, the ArgoCD sync will fail. Mitigation: pick versions known to work with k3s v1.x and document the tested combination.
- **Let's Encrypt rate limits**: If smoke-test provisions/destroys clusters daily and each attempts a real Let's Encrypt certificate, rate limits could be hit. Mitigation: use Let's Encrypt **staging** issuer in CI; production issuer is only activated on real clusters.
- **Single-node limitation**: Traefik on a single-node k3s cluster uses `hostPort` (80/443) rather than a LoadBalancer. This is fine for the dev/CI target but will need revisiting for multi-node or cloud-LB clusters.
- **Public repo email placeholder**: cert-manager requires `spec.acme.email` to be a literal string, not a Secret reference. Mitigation: use a clearly documented placeholder value in the reference repo and require operators to replace it before production certificate issuance.

## Migration Plan

1. Update `terraform/modules/hetzner-k3s/` to pass `--disable=traefik` in the k3s install command.
2. Add `platform/networking/` directory with Traefik and cert-manager ArgoCD Applications.
3. Add a second child Application for cert-manager issuers so `ClusterIssuer` resources are applied only after cert-manager is healthy.
4. Update `clusters/ai-infra-platform/kustomization.yaml` to reference `platform/networking`.
5. Extend `script/verify-platform.sh` with networking health checks.
6. Push to main — ArgoCD auto-syncs the new Applications on the live dev cluster (if present).

**Rollback:** Remove the networking reference from `clusters/ai-infra-platform/kustomization.yaml` and push. ArgoCD will delete the Applications. Re-enable k3s Traefik by removing `--disable=traefik` and reprovisioning.

## Open Questions

- Should the `platform/networking/kustomization.yaml` include both Traefik and cert-manager, or should clusters be able to opt into them independently? For now: both are included when a cluster opts into `platform/networking`. Finer-grained opt-in is a future concern.
- Traefik chart version to pin: needs verification against the k3s version used in `terraform/modules/hetzner-k3s/`. To be confirmed during implementation.
