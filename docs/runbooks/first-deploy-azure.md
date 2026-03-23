# Runbook: First Deploy — Azure

> [!NOTE]
> **Status: Layer 1 Terraform module not yet implemented.**
> This runbook is a skeleton. Layer 1 (Azure cluster provisioning) will be
> filled in when `terraform/modules/azure-k3s/` (or an AKS module) is added.
> Layers 2, 3, and 4 are cloud-agnostic and will apply unchanged once a
> kubeconfig is available.

Provision a Kubernetes cluster on Microsoft Azure and bring up the full
platform stack from scratch. The target is either a single-node k3s cluster on
an Azure VM (cost-optimised, dev/CI) or AKS (production).

---

## Prerequisites

- Admin workstation set up: see [workstation-setup.md](./workstation-setup.md)
- An Azure subscription with Contributor access
- `az` CLI authenticated to your subscription

Additional tools required for Azure:

```sh
# macOS
brew install azure-cli

# Linux
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

Authenticate and set your subscription:

```sh
az login
az account set --subscription "<your-subscription-id>"
```

---

## Layer 1 — Provision the cluster

> [!IMPORTANT]
> Terraform module `terraform/modules/azure-k3s/` is not yet implemented.
> When available, this section will cover:
>
> - Azure credentials setup (`ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`,
>   `ARM_SUBSCRIPTION_ID`, `ARM_TENANT_ID` for a service principal, or
>   Azure CLI auth via `az login`)
> - Azure Blob Storage container creation for Terraform remote state
> - `terraform init` and `terraform apply` for the Azure module
> - Kubeconfig export (for k3s: via Terraform output; for AKS: via
>   `az aks get-credentials`)
>
> Expected target: `Standard_B2s` Azure VM (2 vCPU, 4 GB RAM) with k3s, or
> AKS cluster. Region: `westeurope` or `eastus`.
>
> Relevant variables will include: `cluster_name`, `location`, `vm_size`,
> `ssh_public_key`, `ssh_private_key_path`, `resource_group_name`.

In the meantime, if you have an existing kubeconfig for an Azure-hosted
Kubernetes cluster, set `KUBECONFIG` and continue from Layer 2.

---

## Layer 2 — Bootstrap ArgoCD

Once you have a kubeconfig from Layer 1 (or an existing cluster), Layer 2 is
identical across all cloud providers.

```sh
export KUBECONFIG=~/.kube/ai-infra-azure.yaml

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
> Azure-specific notes for when modules are implemented:
> - `storage` module: will use Azure Disk CSI driver or Azure Files for PVCs
> - `observability` module: compatible with Azure Monitor integration
> - GPU nodes: `NC`-series (NVIDIA T4 / A100) Azure VM SKUs

---

## Layer 4 — Example workloads

> [!NOTE]
> **Status: not yet implemented.** See [first-deploy-hetzner.md — Layer 4](./first-deploy-hetzner.md#layer-4--example-workloads)
> for the planned example list. No Azure-specific changes expected at Layer 4.

---

## Teardown

> [!NOTE]
> Will be documented alongside the Layer 1 module. Expected: `terraform destroy`
> to delete the Azure VM / AKS cluster and remove the resource group. State
> file in Blob Storage will be preserved.

---

## Troubleshooting

> [!NOTE]
> Will be documented alongside the Layer 1 module. Layer 2+ troubleshooting is
> identical to Hetzner — see [first-deploy-hetzner.md — Troubleshooting](./first-deploy-hetzner.md#troubleshooting).
