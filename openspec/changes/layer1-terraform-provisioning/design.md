## Context

The repo currently has no `terraform/` directory — there is no way to provision infrastructure. Layer 1 is the entry point to the entire platform. This design covers the initial Terraform module structure for the Hetzner k3s target and the two shared infrastructure modules (DNS and storage) that platform modules depend on.

The primary target is Hetzner CX22 (€3.29/mo): cheap enough to run in CI on every push, realistic enough to validate real workloads.

## Goals / Non-Goals

**Goals:**
- Establish the canonical Terraform module layout (`modules/`, `shared/`, `examples/`)
- Implement `hetzner-k3s` module: provisions a single-node k3s cluster and outputs kubeconfig
- Implement `shared/dns` module: Cloudflare DNS zone, shared across environments
- Implement `shared/storage` module: S3-compatible bucket for Loki and Velero
- Provide `.tfvars.example` so users know exactly what inputs are required
- Keep state local by default (no remote state backend yet — Layer 1 scope only)

**Non-Goals:**
- GKE, EKS, or HA Hetzner modules (future changes)
- Remote state backend (Terraform Cloud, S3, GCS) — can be added later without breaking the module API
- Secrets management integration — External Secrets Operator is a Layer 3 concern
- Cluster bootstrapping (ArgoCD install) — that belongs to Layer 2

## Decisions

**1. One module per cloud target, not one monolithic module**

Each provider target (`hetzner-k3s`, `gke-standard`, `aws-eks`) is an isolated module under `terraform/modules/`. Shared concerns (DNS, storage) live in `terraform/modules/shared/`.

*Why*: Users activate exactly one target per cluster. Monolithic modules with `count`/`for_each` provider switching are hard to read and maintain. Isolation also means each module can be versioned and tested independently.

*Alternative considered*: A single module with `provider = var.cloud_provider` switch — rejected because it couples unrelated provider APIs and forces users to configure credentials for providers they aren't using.

---

**2. Authentication via environment variables only, no `.tfvars` secrets**

Credentials (`HCLOUD_TOKEN`, `GOOGLE_CREDENTIALS`, `AWS_ACCESS_KEY_ID`) are read from environment variables by the respective Terraform providers. The `.tfvars.example` file documents non-secret inputs (region, node size, domain) only.

*Why*: Prevents accidental credential commits. Aligns with CI/CD best practices (secrets injected as env vars). Matches how the Hetzner, Google, and AWS Terraform providers natively expect credentials.

---

**3. kubeconfig as a Terraform output (not a local file)**

The `hetzner-k3s` module outputs the raw kubeconfig string as a sensitive Terraform output. The caller (bootstrap script) writes it to disk only when needed.

*Why*: Keeping kubeconfig as an output rather than a `local_file` resource avoids coupling the module to a filesystem path. The bootstrap script in Layer 2 can pipe it directly to `kubectl` without leaving files on disk.

---

**4. Shared modules are stand-alone, not sub-modules of any cluster target**

`shared/dns` and `shared/storage` are independent modules, not called by `hetzner-k3s`. Users apply them separately.

*Why*: DNS and storage are shared across multiple cluster targets and environments. Embedding them in `hetzner-k3s` would recreate them on every cluster — wrong semantics. A single shared bucket and DNS zone should exist per account.

## Risks / Trade-offs

- [Local state] Terraform state is local by default — running `terraform apply` from two machines will diverge. → Mitigation: document clearly in module README that remote state backend should be configured before team use. Future change can add a `shared/state-backend/` module.
- [Single-node k3s] The `hetzner-k3s` module is not HA. A node failure destroys the cluster. → Mitigation: this module is explicitly scoped for dev/demo/CI. The HA variant (`hetzner-ha`) is a separate future module.
- [Cloudflare dependency] `shared/dns` hard-codes Cloudflare as the DNS provider. → Mitigation: acceptable for now — the module is opt-in and can be replaced with a cloud-native DNS module later. Noted in module README.
