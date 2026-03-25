<p align="center">
  <img src="./docs/assets/banner-hero.svg" alt="ai-infra-platform" width="100%"/>
</p>

<p align="center">
  <img src="https://img.shields.io/github/actions/workflow/status/your-username/ai-infra-platform/pr-validation.yaml?label=pr%20validation&style=flat-square&color=185FA5" alt="PR Validation"/>
  <img src="https://img.shields.io/github/actions/workflow/status/your-username/ai-infra-platform/dependency-review.yaml?label=dependency%20review&style=flat-square&color=534AB7" alt="Dependency Review"/>
  <img src="https://img.shields.io/badge/kubernetes-1.29%2B-326CE5?style=flat-square&logo=kubernetes&logoColor=white" alt="Kubernetes"/>
  <img src="https://img.shields.io/badge/terraform-1.5%2B-7B42BC?style=flat-square&logo=terraform&logoColor=white" alt="Terraform"/>
  <img src="https://img.shields.io/badge/argocd-2.10%2B-EF7B4D?style=flat-square&logo=argo&logoColor=white" alt="ArgoCD"/>
</p>

<br/>

> A modular, production-grade Kubernetes infrastructure platform for early-stage AI startups.
> Terraform provisions the cluster. ArgoCD owns everything inside it.
> Enable only the modules you need.

> Operational cluster definitions, deploy/smoke workflows, bootstrap scripts,
> and runbooks live in the private `platform-delivery` repository.

<br/>

---

## Architecture

Two layers. One clean handoff.

```
┌─────────────────────────────────────────────────────────┐
│  LAYER 1 — terraform/                                   │
│  Provisions cloud infrastructure via provider APIs.     │
│  Creates the cluster, DNS, storage, secrets backend.    │
│  Outputs kubeconfig → consumed by GitOps bootstrap.     │
└────────────────────────┬────────────────────────────────┘
                         │  terraform output kubeconfig
                         ▼
┌─────────────────────────────────────────────────────────┐
│  LAYER 2 — private cluster declarations + platform/     │
│  ArgoCD bootstrapped once, then owns everything.        │
│  Private ops repo declares which modules are enabled.   │
│  Public repo provides the reusable platform modules.    │
└─────────────────────────────────────────────────────────┘
```

Terraform creates the box. GitOps fills it.

---

<img src="./docs/assets/banner-layer1.svg" alt="Layer 1 — terraform" width="100%"/>

Cloud infrastructure provisioning. One module per provider. Authenticate once with your API token, `terraform apply`, cluster is ready in ~3 minutes.

**Supported targets**

| Module | Provider | Default size | Notes |
|--------|----------|-------------|-------|
| `hetzner-k3s` | Hetzner Cloud | CX22 — €3.29/mo | Single-node k3s, ideal for dev/demo |
| `hetzner-ha` | Hetzner Cloud | 3× CX32 | HA control plane for production |
| `gke-standard` | Google Cloud | e2-standard-2 | GKE Autopilot or Standard |
| `aws-eks` | AWS | t3.medium | EKS with managed node groups |

**Authentication**

```bash
# Hetzner
export HCLOUD_TOKEN="your_token"

# GKE
export GOOGLE_CREDENTIALS="$(cat sa-key.json)"

# EKS
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
```

**Shared infrastructure modules**

```
terraform/shared/
  dns/              # Cloudflare or cloud DNS zone
  storage/          # S3-compatible bucket — Loki + Velero backups
  secrets-backend/  # Vault, AWS SSM, or GCP Secret Manager
```

---

<img src="./docs/assets/banner-layer2.svg" alt="Layer 2 — clusters" width="100%"/>

Environment-specific cluster declarations now live in the private operational
repository. This public repo keeps the reusable platform modules and Terraform
building blocks that those private cluster declarations consume.

**Operational handoff**

```bash
# 1. Provision infrastructure with the modules in this repo
# 2. Bootstrap ArgoCD from the operational repo
# 3. Point ArgoCD at private cluster declarations
# 4. Reconcile the enabled public modules from this repo
```

**Cluster config structure**

```yaml
# clients/<environment>/cluster/kustomization.yaml
resources:
  - ../../../ai-infra-platform/platform/networking
  - ../../../ai-infra-platform/platform/observability
  - ../../../ai-infra-platform/platform/security
  - ../../../ai-infra-platform/platform/storage
  - ../../../ai-infra-platform/platform/ai/qdrant
  - ../../../ai-infra-platform/platform/ai/vllm
```

Enable a module by adding its path. Disable it by removing the line. ArgoCD reconciles.

---

<img src="./docs/assets/banner-layer3.svg" alt="Layer 3 — platform" width="100%"/>

Self-contained, opt-in Helm-based modules. Every module ships with production-grade default values, Grafana dashboards where applicable, and runbooks in `docs/runbooks/`.

**Core modules**

| Module | What it installs | Required |
|--------|-----------------|----------|
| `gitops/` | ArgoCD, Helm repo sources | Yes |
| `networking/ingress-nginx` | Ingress controller | Yes |
| `networking/cert-manager` | Let's Encrypt + ClusterIssuer | Yes |
| `networking/cloudflare-tunnel` | Zero-trust ingress (optional) | No |
| `observability/kube-prometheus-stack` | Prometheus + Grafana + Alertmanager | Yes |
| `observability/loki` | Log aggregation | Recommended |
| `security/external-secrets` | ESO + SecretStore per provider | Yes |
| `security/rbac` | Baseline ClusterRoles | Yes |
| `security/kyverno` | Policy engine | Recommended |
| `storage/velero` | Backup + restore | Recommended |

<br/>

<img src="./docs/assets/banner-ai.svg" alt="platform/ai — AI modules" width="100%"/>

Optional modules for AI workloads. Each is independently opt-in.

| Module | What it installs | Use case |
|--------|-----------------|----------|
| `ai/gpu/` | NVIDIA device plugin, time-slicing config | Any GPU workload |
| `ai/vllm/` | vLLM deployment + autoscaling + OpenAPI spec | LLM inference serving |
| `ai/qdrant/` | Qdrant vector DB + persistence + backup hooks | RAG, semantic search |
| `ai/postgres-operator/` | CloudNativePG + connection pooling + backups | Relational data |
| `ai/redis/` | Redis + Sentinel | Caching, queues |
| `ai/argo-workflows/` | Workflow engine + templates + artifact storage | ML pipelines |

---

<img src="./docs/assets/banner-layer4.svg" alt="Layer 4 — apps" width="100%"/>

Example workloads are intentionally kept out of this public vitrine. The
operational repo owns environment-specific app declarations and overlays.
The public repo stays focused on the reusable platform surface.

---

<img src="./docs/assets/banner-quickstart.svg" alt="Quickstart" width="100%"/>

This repository is now the public vitrine: reusable Terraform modules, platform
manifests, and reference assets. The operational bootstrap flow lives in the
private `platform-delivery` repository that consumes this repo as a submodule.

---

## CI

This public repo keeps only lightweight public CI:

| Workflow | Trigger | What it does |
|---|---|---|
| [`pr-validation`](.github/workflows/pr-validation.yaml) | PR open / sync | `terraform fmt`, `validate`, `plan` (Layer 1); `yamllint`; `shellcheck` |
| [`dependency-review`](.github/workflows/dependency-review.yaml) | PR open / sync | Audits CVEs and action pin integrity |

Live deploy, drift detection, smoke tests, and operator runbooks are maintained
in the private operational repository.

---

## Repository structure

```
ai-infra-platform/
├── terraform/
│   ├── modules/          # one module per cloud provider
│   ├── shared/           # dns, storage, secrets-backend
│   └── examples/         # .tfvars.example per target
├── platform/
│   ├── gitops/
│   ├── networking/
│   ├── observability/
│   ├── security/
│   ├── storage/
│   └── ai/               # gpu, vllm, qdrant, postgres, redis, workflows
├── .github/workflows/    # public validation and dependency review
└── docs/assets/          # README visuals
```

---

## Public vs. Operational

- Public repo: reusable Terraform modules, Kubernetes platform manifests, reference assets
- Private repo: live cluster declarations, bootstrap scripts, deploy/smoke workflows, operator runbooks, internal specs

---

<br/>

<p align="center">
  <sub>Built and maintained as part of a fractional AI infrastructure service for early-stage startups.<br/>
  Need this running for your team? <a href="https://your-service-page-url">Learn more →</a></sub>
</p>
