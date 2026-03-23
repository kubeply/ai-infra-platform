# Runbook: First Deploy — Hetzner Cloud

Provision a k3s cluster on Hetzner Cloud and bring up the full platform stack
from scratch. This runbook covers all four layers; Layers 3 and 4 will be
expanded as platform modules are implemented.

**Target infrastructure:** Hetzner CX23 — 2 vCPU, 4 GB RAM, 40 GB SSD (~€3.29/mo)

---

## Prerequisites

- Admin workstation set up: see [workstation-setup.md](./workstation-setup.md)
- A Hetzner Cloud account and project
- A Hetzner Object Storage bucket named `terraform-state-ai-infra` in region
  `fsn1` (create once, before your first `terraform init`)

---

## Layer 1 — Provision the cluster

### 1.1 Set credentials

```sh
# Hetzner Cloud API token (Read & Write)
# console.hetzner.cloud → Project → Security → API Tokens
export HCLOUD_TOKEN="<your-hetzner-api-token>"

# Hetzner Object Storage keys (Terraform S3 backend)
# console.hetzner.cloud → Object Storage → Access Keys → Generate key
export AWS_ACCESS_KEY_ID="<your-object-storage-access-key>"
export AWS_SECRET_ACCESS_KEY="<your-object-storage-secret-key>"
```

Verify token access:

```sh
curl -sf -H "Authorization: Bearer ${HCLOUD_TOKEN}" \
  https://api.hetzner.cloud/v1/servers | python3 -m json.tool | head -5
```

### 1.2 Create a tfvars file

```sh
cp terraform/examples/hetzner-k3s.tfvars.example terraform/examples/hetzner-k3s.tfvars
```

Edit `terraform/examples/hetzner-k3s.tfvars`:

```hcl
cluster_name     = "ai-infra-dev"           # Unique name in your Hetzner project
location         = "fsn1"                   # nbg1 · fsn1 · hel1 · ash · sin
ssh_public_key   = "ssh-ed25519 AAAA..."    # cat ~/.ssh/ai-infra.pub
ssh_private_key_path = "~/.ssh/ai-infra"

# Optional: pin k3s for reproducibility
# k3s_version = "v1.31.0+k3s1"

# Optional: upgrade server for more workloads
# server_type = "cx33"   # 4 vCPU / 8 GB RAM
```

> [!WARNING]
> Never commit `hetzner-k3s.tfvars` — it contains your SSH public key and
> cluster name. The file is gitignored, but double-check before any `git add`.

### 1.3 Init and apply

```sh
cd terraform/modules/hetzner-k3s

terraform init \
  -backend-config="key=ai-infra-dev/terraform.tfstate"

terraform apply \
  -var-file=../../examples/hetzner-k3s.tfvars
```

Expected duration: **3–6 minutes.**

### 1.4 Export the kubeconfig

```sh
terraform output -raw kubeconfig > ~/.kube/ai-infra-dev.yaml
chmod 600 ~/.kube/ai-infra-dev.yaml
export KUBECONFIG=~/.kube/ai-infra-dev.yaml
```

Verify:

```sh
kubectl get nodes
# NAME           STATUS   ROLES                  AGE   VERSION
# ai-infra-dev   Ready    control-plane,master   2m    v1.31.x+k3s1
```

---

## Layer 2 — Bootstrap ArgoCD

Run from the **repository root**:

```sh
cd /path/to/ai-infra-platform

KUBECONFIG=~/.kube/ai-infra-dev.yaml bash script/bootstrap-cluster.sh
```

The script runs four steps:

| Step | What happens |
|---|---|
| `[1/4]` | Installs ArgoCD via Helm (OCI, chart 7.8.0, `--wait`) |
| `[2/4]` | Waits for `argocd-server` and `argocd-application-controller` rollout |
| `[3/4]` | Applies `bootstrap/root-application.yaml` (App of Apps entry point) |
| `[4/4]` | Polls until the root Application is `Synced` and `Healthy` (up to 120 s) |

Expected duration: **4–8 minutes** (image pulls on a fresh node).

When `Bootstrap complete.` is printed, ArgoCD is watching `clusters/dev/` and
self-managing its own Helm release via GitOps.

### Verify Layer 2

```sh
KUBECONFIG=~/.kube/ai-infra-dev.yaml bash script/verify-platform.sh
```

Expected final lines:

```
==> [6/6] Root Application sync status
    Root Application: sync=Synced health=Healthy

Platform verification passed.
```

---

## Layer 3 — Platform modules

> [!NOTE]
> **Status: not yet implemented.** Platform module Helm resources will be added
> here as each module is built. This section will be expanded for each module
> that is enabled.

Layer 3 consists of opt-in platform modules declared in `clusters/dev/` and
managed by ArgoCD. Modules are activated by adding the corresponding ArgoCD
Application to `clusters/dev/kustomization.yaml`.

Planned core modules (enable in any order after Layer 2):

| Module | Directory | Purpose |
|---|---|---|
| `networking` | `platform/networking/` | Ingress controller, cert-manager, external-dns |
| `observability` | `platform/observability/` | Prometheus, Grafana, Loki |
| `security` | `platform/security/` | Falco, network policies, OPA |
| `storage` | `platform/storage/` | Velero backups, PVC provisioner |

Planned AI modules (enable after core modules):

| Module | Directory | Purpose |
|---|---|---|
| `gpu` | `platform/ai/gpu/` | NVIDIA device plugin, GPU node taints |
| `vllm` | `platform/ai/vllm/` | LLM inference server |
| `qdrant` | `platform/ai/qdrant/` | Vector database |
| `postgres-operator` | `platform/ai/postgres-operator/` | Managed PostgreSQL |
| `redis` | `platform/ai/redis/` | In-memory cache |
| `argo-workflows` | `platform/ai/argo-workflows/` | ML pipeline orchestration |

To enable a module once implemented, add its Application to
`clusters/dev/kustomization.yaml` and push to `main`. ArgoCD will reconcile
automatically.

---

## Layer 4 — Example workloads

> [!NOTE]
> **Status: not yet implemented.** Example workload manifests will be added to
> `apps/` as Layer 3 modules are stabilised. This section will be expanded with
> deployment instructions for each example app.

Layer 4 shows how client workloads connect to the platform layer. Each example
in `apps/` follows the base/overlay pattern and assumes specific Layer 3
modules are enabled.

Planned examples:

| App | Requires | Purpose |
|---|---|---|
| `inference-api` | `gpu`, `vllm` | Example LLM API behind an ingress |
| `rag-pipeline` | `qdrant`, `postgres-operator`, `argo-workflows` | Retrieval-augmented generation pipeline |
| `monitoring-demo` | `observability` | App pre-wired with Prometheus metrics |

---

## Storing the kubeconfig for CI

If you want the `live-deploy` GitHub Actions workflow to target this cluster,
encode the kubeconfig and add it as a secret:

```sh
base64 -i ~/.kube/ai-infra-dev.yaml | tr -d '\n'
# Copy output → GitHub → Settings → Secrets → LIVE_CLUSTER_KUBECONFIG
```

See [ci-secrets.md](./ci-secrets.md) for the full secrets reference.

---

## Teardown

```sh
cd terraform/modules/hetzner-k3s

terraform destroy \
  -var-file=../../examples/hetzner-k3s.tfvars
```

Deletes the server and SSH key from Hetzner. The state file in Object Storage
is preserved. To fully clean up, delete `ai-infra-dev/terraform.tfstate` from
the `terraform-state-ai-infra` bucket.

---

## Troubleshooting

### `terraform init` fails with `NoCredentialProviders`

```sh
echo $AWS_ACCESS_KEY_ID && echo $AWS_SECRET_ACCESS_KEY  # must be non-empty
```

Re-export and retry.

### Node shows `NotReady` after apply

k3s may still be initialising. Wait 30 seconds and retry. If it persists:

```sh
SERVER_IP=$(terraform output -raw server_ip)
ssh -i ~/.ssh/ai-infra root@"${SERVER_IP}" \
  "systemctl status k3s && kubectl get nodes"
```

### Bootstrap fails at `[1/4]` — `helm: command not found` or OCI unsupported

Helm 3.8+ is required for OCI chart support. Verify:

```sh
helm version --short   # must be v3.8.0 or later
```

See [workstation-setup.md](./workstation-setup.md) to upgrade.

### Bootstrap times out at `[4/4]` — root Application not Synced

```sh
kubectl get application root -n argocd -o yaml | grep -A 10 "status:"
kubectl logs -n argocd deploy/argocd-repo-server | tail -20
```

Common causes:
- `repoURL` in `bootstrap/root-application.yaml` doesn't match `git remote -v`
- ArgoCD cannot reach GitHub (network/proxy issue)

### `verify-platform.sh` step `[6/6]` — `sync=OutOfSync`

A diff was detected between the cluster and `clusters/dev/`. Wait a few seconds
for ArgoCD to auto-reconcile, then re-run verify. To force an immediate sync:

```sh
kubectl patch application root -n argocd \
  --type merge -p '{"operation":{"sync":{}}}'
```
