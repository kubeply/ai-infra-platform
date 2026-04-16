<p align="center">
  <img src="./docs/assets/banner-hero.svg" alt="ai-infra-platform" width="100%"/>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/kubernetes-1.29%2B-326CE5?style=flat-square&logo=kubernetes&logoColor=white" alt="Kubernetes"/>
  <img src="https://img.shields.io/badge/terraform-1.5%2B-7B42BC?style=flat-square&logo=terraform&logoColor=white" alt="Terraform"/>
  <img src="https://img.shields.io/badge/argocd-2.10%2B-EF7B4D?style=flat-square&logo=argo&logoColor=white" alt="ArgoCD"/>
</p>

<br/>

> A modular, production-grade Kubernetes infrastructure platform for early-stage AI startups.
> Terraform provisions the cluster. ArgoCD owns everything inside it.
> Enable only the modules you need.

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
│  LAYER 2 — clusters/ + platform/                        │
│  ArgoCD bootstrapped once, then owns everything.        │
│  Public repo ships the shared cluster baseline.         │
│  Private ops repo adds overlays and environment hooks.  │
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

This public repo now carries the shared cluster baseline used during first
bootstrap. Private operational repos can still add overlays, customer-specific
apps, and environment hooks on top, but Layer 2 no longer depends on a private
Git repository to start reconciling.

**Operational handoff**

```bash
# 1. Provision infrastructure with the modules in this repo
# 2. Bootstrap ArgoCD from the operational repo
# 3. Point ArgoCD at the shared public cluster baseline
# 4. Layer on private overlays only when needed
```

**Cluster config structure**

```yaml
# clusters/acme/kustomization.yaml
resources:
  - ../../platform/gitops
  - ../../platform/networking
  - ../../platform/observability
  - ../../platform/security
  - ../../platform/storage
  - ../../platform/ai/qdrant # 🚧
  - ../../platform/ai/vllm   # 🚧
```

Enable a module by adding its path. Disable it by removing the line. ArgoCD reconciles.

`🚧` = work in progress / planned

---

<img src="./docs/assets/banner-layer3.svg" alt="Layer 3 — platform" width="100%"/>

Self-contained, opt-in Helm-based modules. Every module ships with production-grade
default values and Grafana dashboards where applicable.

**Core modules**

| Module | What it installs | Required |
|--------|-----------------|----------|
| `gitops/` | ArgoCD, Sealed Secrets | Yes |
| `networking/traefik` | Ingress controller | Yes |
| `networking/cert-manager` | Let's Encrypt + ClusterIssuer | Yes |
| `observability/kube-prometheus-stack` | Prometheus + Grafana + Alertmanager | Yes |
| `observability/loki` | Log aggregation | Recommended |
| `security/external-secrets` | ESO + SecretStore per provider | Yes |
| `security/rbac` | Baseline ClusterRoles | Yes |
| `security/kyverno` | Policy engine | Recommended |
| `storage/velero` | Backup + restore | Recommended |

Grafana stays internal by default in the public example cluster. If you want a
public HTTPS endpoint, add the ingress hostname/TLS settings from a private
overlay with a real DNS name instead of relying on the example baseline.

<br/>

<img src="./docs/assets/banner-ai.svg" alt="platform/ai — AI modules" width="100%"/>

Optional modules for AI workloads. Each is independently opt-in.

| Module | What it installs | Use case |
|--------|-----------------|----------|
| `ai/gpu/` `🚧` | NVIDIA device plugin, time-slicing config | Any GPU workload |
| `ai/vllm/` `🚧` | vLLM deployment + autoscaling + OpenAPI spec | LLM inference serving |
| `ai/qdrant/` `🚧` | Qdrant vector DB + persistence + backup hooks | RAG, semantic search |
| `ai/postgres-operator/` | CloudNativePG + PgBouncer + backups | Relational data |
| `ai/redis/` | Valkey-compatible Redis operator | Caching, queues, ephemeral state |
| `ai/argo-workflows/` `🚧` | Workflow engine + templates + artifact storage | ML pipelines |

**PostgreSQL**

`platform/ai/postgres-operator/` installs the CloudNativePG operator and the
Barman Cloud backup plugin with pinned Helm chart versions. It stays optional:
the public `clusters/acme` baseline does not create client PostgreSQL clusters
or logical databases by default.

Use the examples under `platform/ai/postgres-operator/examples/` from a
client-specific entrypoint when a workload needs a database, access role,
PgBouncer pooler, connection secret, or PostgreSQL-native backup policy.

**Redis-Compatible Valkey**

`platform/ai/redis/` installs the OT Redis Operator with pinned Helm chart
version `0.24.0`. It stays optional: the public `clusters/acme` baseline does
not create Redis-compatible instances by default.

Use the examples under `platform/ai/redis/examples/` from a client-specific
entrypoint when a workload needs an ephemeral cache, a persistent standalone
Valkey instance, replicated Redis-compatible capacity, or a workload connection
secret. The first server image family is pinned to `valkey/valkey:9.0.3`
because Valkey is the Redis-compatible open source default for this module.

---

<img src="./docs/assets/banner-layer4.svg" alt="Layer 4 — apps" width="100%"/>

Example workloads are intentionally kept out of this public vitrine. The
operational repo owns environment-specific app declarations and overlays.
The public repo stays focused on the reusable platform surface.

---

<img src="./docs/assets/banner-quickstart.svg" alt="Quickstart" width="100%"/>

This repository is now the public vitrine: reusable Terraform modules, shared
cluster declarations, platform manifests, and reference assets. The
operational bootstrap flow lives in a private operations repository that
consumes this repo as a pinned baseline.

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
├── clusters/
│   └── acme/              # example public cluster baseline
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
│   └── ai/               # optional gpu, vllm, qdrant, postgres, redis, workflows
├── .github/workflows/    # public validation and dependency review
└── docs/assets/          # README visuals
```

---

<br/>

<p align="center">
  <sub>Built and maintained as part of a fractional AI infrastructure service for early-stage startups.<br/>
  Need this running for your team? <a href="https://cal.eu/kubeply/discovery">Learn more →</a></sub>
</p>
