# Argo CD Image Updater

`platform/gitops/image-updater/` installs Argo CD Image Updater as an optional
GitOps module. It is intentionally separate from `platform/gitops/` so clusters
can opt into image automation only after their app repositories and registry
credentials are ready.

The controller expects these secrets to be provided by the private bootstrap or
client overlay:

| Secret | Namespace | Purpose |
|---|---|---|
| `argocd-image-updater-git` | `argocd` | Git credentials for writeback commits |
| `argocd-image-updater-ghcr` | `argocd` | GHCR credentials in `username:token` format |

Workload-specific `ImageUpdater` resources should live with the app overlay
they update. The examples in `examples/` show the preferred short-SHA tag,
Kustomize image writeback convention, and workflow loop guard.
