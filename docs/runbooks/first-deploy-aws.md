# Runbook: First Deploy — AWS

> [!NOTE]
> **Status: Layer 1 Terraform module not yet implemented.**
> This runbook is a skeleton. Layer 1 (AWS cluster provisioning) will be
> filled in when `terraform/modules/aws-k3s/` (or an EKS module) is added.
> Layers 2, 3, and 4 are cloud-agnostic and will apply unchanged once a
> kubeconfig is available.

Provision a Kubernetes cluster on AWS and bring up the full platform stack
from scratch. The target is either a single-node k3s cluster on EC2 (cost-
optimised, dev/CI) or EKS (production).

---

## Prerequisites

- Admin workstation set up: see [workstation-setup.md](./workstation-setup.md)
- An AWS account with IAM permissions to create EC2 instances, VPCs, S3
  buckets, and (if using EKS) EKS clusters
- AWS CLI configured locally (`aws configure` or environment variables)

Additional tools required for AWS:

```sh
# macOS
brew install awscli

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip awscliv2.zip && sudo ./aws/install
```

---

## Layer 1 — Provision the cluster

> [!IMPORTANT]
> Terraform module `terraform/modules/aws-k3s/` is not yet implemented.
> When available, this section will cover:
>
> - AWS credentials setup (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`,
>   `AWS_DEFAULT_REGION`)
> - S3 bucket creation for Terraform remote state
> - `terraform init` and `terraform apply` for the AWS module
> - Kubeconfig export from Terraform output
>
> Expected target: EC2 `t3.medium` (2 vCPU, 4 GB RAM) with k3s, in a public
> subnet. EKS support planned as a separate module.
>
> Relevant variables will include: `cluster_name`, `region`, `instance_type`,
> `ssh_public_key`, `ssh_private_key_path`.

In the meantime, if you have an existing kubeconfig for an AWS-hosted
Kubernetes cluster, set `KUBECONFIG` and continue from Layer 2.

---

## Layer 2 — Bootstrap ArgoCD

Once you have a kubeconfig from Layer 1 (or an existing cluster), Layer 2 is
identical across all cloud providers.

```sh
export KUBECONFIG=~/.kube/ai-infra-aws.yaml

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
> AWS-specific notes for when modules are implemented:
> - `storage` module: will use AWS EBS CSI driver or EFS for PVCs
> - `observability` module: compatible with CloudWatch integration
> - GPU nodes: `p3`/`p4` instance types with NVIDIA AMIs

---

## Layer 4 — Example workloads

> [!NOTE]
> **Status: not yet implemented.** See [first-deploy-hetzner.md — Layer 4](./first-deploy-hetzner.md#layer-4--example-workloads)
> for the planned example list. No AWS-specific changes expected at Layer 4.

---

## Teardown

> [!NOTE]
> Will be documented alongside the Layer 1 module. Expected: `terraform destroy`
> to terminate the EC2 instance and clean up VPC resources. State file in S3
> will be preserved.

---

## Troubleshooting

> [!NOTE]
> Will be documented alongside the Layer 1 module. Layer 2+ troubleshooting is
> identical to Hetzner — see [first-deploy-hetzner.md — Troubleshooting](./first-deploy-hetzner.md#troubleshooting).
