# Runbook: Admin Workstation Setup

Install and configure all tools required to provision and operate the
ai-infra-platform from your local machine. Run this once before any
first-deploy runbook.

---

## Required tools

| Tool | Min version | Purpose |
|---|---|---|
| `git` | 2.x | Clone and push to this repository |
| `terraform` | 1.6+ | Provision cloud infrastructure (Layer 1) |
| `helm` | 3.8+ | Bootstrap ArgoCD via OCI chart (Layer 2) |
| `kubectl` | 1.26+ | Interact with Kubernetes clusters |
| `ssh` | any | Kubeconfig retrieval from provisioned nodes |
| `python3` | 3.8+ | Used by the Terraform kubeconfig fetch script |

## Recommended tools

| Tool | Purpose |
|---|---|
| `k9s` | Terminal UI for Kubernetes — faster than `kubectl` for day-to-day ops |
| `argocd` CLI | Manage ArgoCD Applications without the web UI |
| `gh` | GitHub CLI — trigger workflows, manage secrets from the terminal |

---

## macOS

### 1. Install Homebrew (if not installed)

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2. Install required tools

```sh
brew install git terraform helm kubectl
```

`ssh` and `python3` are pre-installed on macOS. Verify:

```sh
ssh -V
python3 --version
```

### 3. Install recommended tools

```sh
brew install k9s argocd gh
```

---

## Linux (Ubuntu / Debian)

### 1. System packages

```sh
sudo apt-get update
sudo apt-get install -y git curl unzip ssh python3
```

### 2. Terraform

HashiCorp publishes an official apt repository:

```sh
wget -O - https://apt.releases.hashicorp.com/gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt-get update && sudo apt-get install -y terraform
```

### 3. Helm

```sh
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### 4. kubectl

```sh
KUBECTL_VERSION=$(curl -sfL https://dl.k8s.io/release/stable.txt)
curl -sfLo /usr/local/bin/kubectl \
  "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
chmod +x /usr/local/bin/kubectl
```

### 5. Recommended tools

```sh
# k9s
curl -sfL https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz \
  | sudo tar -xz -C /usr/local/bin k9s

# argocd CLI
curl -sfLo /usr/local/bin/argocd \
  https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x /usr/local/bin/argocd

# GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
  https://cli.github.com/packages stable main" \
  | sudo tee /etc/apt/sources.list.d/github-cli.list
sudo apt-get update && sudo apt-get install -y gh
```

---

## Verify your installation

Run this block to confirm all required tools are present and meet the minimum
version requirements:

```sh
echo "==> git"        && git --version
echo "==> terraform"  && terraform version | head -1
echo "==> helm"       && helm version --short
echo "==> kubectl"    && kubectl version --client --short 2>/dev/null || kubectl version --client
echo "==> ssh"        && ssh -V
echo "==> python3"    && python3 --version
echo ""
echo "==> k9s (optional)"    && k9s version --short 2>/dev/null || echo "not installed"
echo "==> argocd (optional)" && argocd version --client --short 2>/dev/null || echo "not installed"
echo "==> gh (optional)"     && gh --version | head -1 2>/dev/null || echo "not installed"
```

Expected minimum output:

```
==> git
git version 2.x.x
==> terraform
Terraform v1.6.x
==> helm
v3.8.x+...
==> kubectl
Client Version: v1.26.x
==> ssh
OpenSSH_x.x...
==> python3
Python 3.8.x
```

---

## SSH key setup

The Terraform Hetzner module SSHs into the provisioned server to retrieve the
kubeconfig. You need a local SSH key pair.

If you do not already have one, generate a dedicated key for this platform:

```sh
ssh-keygen -t ed25519 -C "ai-infra-platform" -f ~/.ssh/ai-infra -N ""
```

This creates:
- `~/.ssh/ai-infra` — private key
- `~/.ssh/ai-infra.pub` — public key (deployed to servers by Terraform)

> [!WARNING]
> Never commit `~/.ssh/ai-infra` or add it to the repository. Keep it local
> and set permissions to `600` (`chmod 600 ~/.ssh/ai-infra`).

Reference `~/.ssh/ai-infra` as `ssh_private_key_path` and the contents of
`~/.ssh/ai-infra.pub` as `ssh_public_key` in your tfvars file.

---

## Next steps

Once your workstation is set up, follow a provider-specific first-deploy runbook:

- [Hetzner Cloud](./first-deploy-hetzner.md) — **Implemented.** CX23 server, k3s, €3.29/mo.
- [AWS](./first-deploy-aws.md) — Planned. EC2 + k3s or EKS.
- [GCP](./first-deploy-gcp.md) — Planned. GCE + k3s or GKE.
- [Azure](./first-deploy-azure.md) — Planned. Azure VM + k3s or AKS.
