## Why

Layer 2 delivers a working GitOps engine (ArgoCD) but no cluster is yet capable of serving HTTPS traffic. Every higher-level module — observability dashboards, AI workload UIs, client-facing services — needs a working ingress layer with valid TLS before it can be exposed. This is the logical first Layer 3 module.

## What Changes

- Introduce `platform/` as the Layer 3 root directory with a Kustomize structure for opt-in modules.
- Add `platform/networking/` as the first opt-in module, consisting of two sub-components:
  - **Traefik** ingress controller managed via GitOps (k3s ships Traefik by default, but this replaces the unmanaged install with a pinned, ArgoCD-owned Helm release).
  - **cert-manager** for automatic TLS certificate provisioning via Let's Encrypt (HTTP-01 or DNS-01 challenge).
- Update `clusters/ai-infra-platform/kustomization.yaml` to opt into the networking module.
- Extend `script/verify-platform.sh` to include Layer 3 networking health checks.

## Capabilities

### New Capabilities

- `platform-ingress`: Traefik ingress controller deployed as a GitOps-managed Helm release; replaces the default k3s Traefik install. Exposes HTTP/HTTPS on the node's public IP. Pinned chart version for Renovate detection.
- `platform-tls`: cert-manager deployed as a GitOps-managed Helm release. Provisions a ClusterIssuer for Let's Encrypt (staging + production). Issues TLS certificates automatically for Ingress resources via HTTP-01 challenge.

### Modified Capabilities

- `cluster-declarations`: `clusters/ai-infra-platform/kustomization.yaml` gains a reference to the networking module.

## Impact

- **platform/**: new directory and first module (`platform/networking/`).
- **clusters/ai-infra-platform/kustomization.yaml**: adds networking module to the opt-in list.
- **script/verify-platform.sh**: extends health checks to cover Traefik and cert-manager deployments.
- **terraform/modules/hetzner-k3s/**: adds `--disable=traefik` so the GitOps-managed Traefik release does not conflict with the bundled k3s add-on.
- This remains the first Layer 3 module, with a small Layer 1 prerequisite in the Hetzner provisioning module.
- No impact on Layer 4 (apps/) yet; the apps layer will reference Ingress resources once this module is live.
