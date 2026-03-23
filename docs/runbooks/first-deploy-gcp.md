# Runbook: First Deploy — GCP

> [!NOTE]
> **Status: Layer 1 Terraform module not yet implemented.**
> This runbook is a skeleton. Layer 1 (GCP cluster provisioning) will be
> filled in when `terraform/modules/gcp-k3s/` (or a GKE module) is added.
> Layers 2, 3, and 4 are cloud-agnostic and will apply unchanged once a
> kubeconfig is available.

Provision a Kubernetes cluster on Google Cloud Platform and bring up the full
platform stack from scratch. The target is either a single-node k3s cluster on
a GCE instance (cost-optimised, dev/CI) or GKE Autopilot (production).

---

## Prerequisites

- Admin workstation set up: see [workstation-setup.md](./workstation-setup.md)
- A GCP project with billing enabled
- `gcloud` CLI authenticated to your project

Additional tools required for GCP:

```sh
# macOS
brew install --cask google-cloud-sdk

# Linux
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
```

Authenticate and set your project:

```sh
gcloud auth login
gcloud auth application-default login
gcloud config set project <your-gcp-project-id>
```

---

## Layer 1 — Provision the cluster

> [!IMPORTANT]
> Terraform module `terraform/modules/gcp-k3s/` is not yet implemented.
> When available, this section will cover:
>
> - GCP credentials setup (`GOOGLE_CREDENTIALS` or Application Default
>   Credentials via `gcloud auth application-default login`)
> - GCS bucket creation for Terraform remote state
> - `terraform init` and `terraform apply` for the GCP module
> - Kubeconfig export (for k3s: via Terraform output; for GKE: via
>   `gcloud container clusters get-credentials`)
>
> Expected target: `e2-standard-2` GCE instance (2 vCPU, 8 GB RAM) with k3s,
> or GKE Autopilot cluster. Region: `europe-west1` or `us-central1`.
>
> Relevant variables will include: `cluster_name`, `project`, `region`,
> `zone`, `machine_type`, `ssh_public_key`, `ssh_private_key_path`.

In the meantime, if you have an existing kubeconfig for a GCP-hosted
Kubernetes cluster, set `KUBECONFIG` and continue from Layer 2.

---

## Layer 2 — Bootstrap ArgoCD

Once you have a kubeconfig from Layer 1 (or an existing cluster), Layer 2 is
identical across all cloud providers.

```sh
export KUBECONFIG=~/.kube/ai-infra-gcp.yaml

cd /path/to/ai-infra-platform
bash script/bootstrap-cluster.sh
```

See [first-deploy-hetzner.md — Layer 2](./first-deploy-hetzner.md#layer-2--bootstrap-argocd)
for the full step-by-step description and expected output.

Verify:

```sh
bash script/verify-platform.sh
```

---

## Layer 3 — Platform modules

> [!NOTE]
> **Status: not yet implemented.** See [first-deploy-hetzner.md — Layer 3](./first-deploy-hetzner.md#layer-3--platform-modules)
> for the planned module list.
>
> GCP-specific notes for when modules are implemented:
> - `storage` module: will use GCP Persistent Disk CSI driver or Filestore
> - `observability` module: compatible with Google Cloud Monitoring integration
> - GPU nodes: `nvidia-tesla-t4` or `nvidia-l4` GCE accelerator types

---

## Layer 4 — Example workloads

> [!NOTE]
> **Status: not yet implemented.** See [first-deploy-hetzner.md — Layer 4](./first-deploy-hetzner.md#layer-4--example-workloads)
> for the planned example list. No GCP-specific changes expected at Layer 4.

---

## Teardown

> [!NOTE]
> Will be documented alongside the Layer 1 module. Expected: `terraform destroy`
> to delete the GCE instance / GKE cluster and clean up networking resources.
> State file in GCS will be preserved.

---

## Troubleshooting

> [!NOTE]
> Will be documented alongside the Layer 1 module. Layer 2+ troubleshooting is
> identical to Hetzner — see [first-deploy-hetzner.md — Troubleshooting](./first-deploy-hetzner.md#troubleshooting).
