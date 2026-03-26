# terraform/modules/hetzner-k3s

Provisions a single-node k3s cluster on a Hetzner Cloud server. Outputs a kubeconfig string consumed by the GitOps bootstrap in Layer 2.

**Target**: Hetzner CX33 — 4 vCPU, 8 GB RAM, 80 GB SSD. Suitable for demo and platform workloads.

---

## Authentication

Set `HCLOUD_TOKEN` in your environment before running any Terraform commands. The provider reads it automatically — no credentials go in `.tfvars` files.

```bash
export HCLOUD_TOKEN="your_hetzner_api_token"
```

You can create a token at [console.hetzner.cloud](https://console.hetzner.cloud) → Project → Security → API Tokens.

---

## Quick start

```bash
# Copy and edit the example vars file
cp ../../examples/hetzner-k3s.tfvars.example ../../examples/hetzner-k3s.tfvars
# Edit: set cluster_name, location, ssh_public_key

export HCLOUD_TOKEN="your_token"

terraform init
terraform apply -var-file=../../examples/hetzner-k3s.tfvars

# Retrieve the kubeconfig
terraform output -raw kubeconfig > ~/.kube/ai-infra-platform.yaml
kubectl --kubeconfig ~/.kube/ai-infra-platform.yaml get nodes
```

---

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `cluster_name` | `string` | required | Name for the server and cluster. Used as the Hetzner server name and SSH key prefix. |
| `location` | `string` | required | Hetzner datacenter region. Options: `nbg1`, `fsn1`, `hel1`, `ash`, `sin`. |
| `server_type` | `string` | `cx33` | Hetzner server type. `cx33` is the default for demo/platform use. Use `cx23` only for smaller dev/CI clusters. |
| `ssh_public_key` | `string` | required | SSH public key content. Deployed to the server for post-provision access. |
| `ssh_private_key_path` | `string` | `~/.ssh/id_rsa` | Path to the corresponding SSH private key on this machine. Used to retrieve the kubeconfig. |
| `k3s_version` | `string` | `""` | k3s version to install (e.g. `v1.29.2+k3s1`). Empty = latest stable. |

---

## Outputs

| Name | Type | Sensitive | Description |
|------|------|-----------|-------------|
| `kubeconfig` | `string` | yes | kubeconfig for the provisioned cluster. Pipe to `kubectl` or write to disk only when needed. |
| `server_ip` | `string` | no | Public IPv4 address of the k3s server. |
| `server_id` | `string` | no | Hetzner Cloud server ID. |

---

## How it works

1. An `hcloud_server` is created with Ubuntu 24.04 and a cloud-init script.
2. Cloud-init installs k3s via the official install script (`https://get.k3s.io`) with `--tls-san <public_ip>` so the API server certificate is valid for remote access.
3. A `null_resource` SSHs into the server and waits until k3s reports a `Ready` node.
4. An `external` data source SSHs to the server and reads `/etc/rancher/k3s/k3s.yaml`, replacing `127.0.0.1` with the server's public IP.
5. The patched kubeconfig is exposed as a sensitive Terraform output.

**Why output kubeconfig instead of writing a file?**
Keeping it as an output avoids coupling the module to a filesystem path. The Layer 2 bootstrap script pipes it directly to `kubectl` without leaving files on disk.

---

## State and teardown

State is stored locally by default. To tear down:

```bash
terraform destroy -var-file=../../examples/hetzner-k3s.tfvars
```

This deletes the server and SSH key from Hetzner. No manual cleanup required.

> **Note:** Local state means running `terraform apply` from two machines will diverge. Configure a remote backend (S3, Terraform Cloud) before team use.

---

## Local dependencies

The post-provision kubeconfig fetch requires:
- `ssh` — standard on macOS/Linux
- `python3` — standard on macOS/Linux; used to format the kubeconfig as JSON for the external data source
