## Context

The repo currently has no CI/CD. Every push to `main` is unvalidated and deploying to Hetzner requires manual `terraform apply` + `bootstrap-cluster.sh`. The platform aspires to be a public reference implementation — CI is the credibility signal that it has been operated, not just installed.

Four workflows cover the full lifecycle:

| Workflow | Trigger | Purpose |
|---|---|---|
| `pr-validation` | PR open/sync | Static validation gate |
| `live-deploy` | push to `main` | Deploy Layers 2-4 to live demo cluster |
| `infra-smoke-test` | daily cron 03:00 UTC (04:00 CET) | Full Layer 1 validation: provision → verify → destroy |
| `deploy` | manual | Production provisioning |
| `dependency-review` | PR open/sync | Pin audit |

Secrets required: `HCLOUD_TOKEN` (mandatory for smoke-test and deploy), `SSH_PRIVATE_KEY` (cluster access), `TF_API_TOKEN` (optional, Terraform Cloud remote state).

## Goals / Non-Goals

**Goals:**
- Block merges on Terraform/YAML/Kubernetes/shell errors detected statically.
- Prove platform correctness on every merge to `main` by deploying to the live demo cluster (Layers 2-4).
- Prove Layer 1 Terraform correctness daily via a full ephemeral provision → verify → destroy cycle.
- Provide a one-click manual path to deploy Layer 1 + bootstrap.
- Keep pinned GitHub Actions digests auditable and updated.

**Non-Goals:**
- Multi-cloud CI (GCP/AWS): Hetzner is the only active target; other clouds are validated statically via `terraform validate` only.
- Blue/green or canary deployments: out of scope for v1.
- Application-level integration tests beyond `verify-platform.sh`.
- Notifications (Slack, PagerDuty): deferred.

## Decisions

### Terraform plan on PRs, apply only on deploy

**Decision**: `pr-validation` runs `terraform plan` (read-only), never `apply`. The manual `deploy` workflow is the only path to `apply`.

**Rationale**: `plan` catches drift and config errors without mutating real infrastructure. Applying on every PR would be expensive and dangerous. A separate manual `deploy` workflow gives explicit human intent.

**Alternative considered**: Terraform Cloud run triggers on PR — rejected because it couples CI to a paid service and adds latency without adding value over local `plan`.

### Split smoke-test: live deploy on merge, ephemeral cluster daily

**Decision**: Two separate workflows cover CI validation:

1. **`live-deploy`** — triggers on every push to `main`. Deploys platform changes (Layers 2-4) to the live demo cluster by triggering an ArgoCD sync. If the sync fails or any Application becomes degraded, ArgoCD's built-in rollback reverts to the previous revision. No Terraform is involved.

2. **`infra-smoke-test`** — triggers via daily cron at **03:00 UTC (04:00 CET)**. Provisions a fresh ephemeral Hetzner CX22 via `terraform apply`, bootstraps core modules, runs `verify-platform.sh`, then destroys everything with `terraform destroy`. This is the only place Layer 1 Terraform is exercised end-to-end.

**Rationale**: Running `terraform apply` on every push to `main` would add ~5 minutes of latency to every merge and €0.01/run in infra costs. The vast majority of commits change platform manifests (Layer 2-4), not Terraform. Decoupling the two loops gives fast merge feedback (seconds via ArgoCD) while still catching Terraform regressions daily — before anyone needs to run `deploy` for real.

**Alternative considered**: Ephemeral cluster on every push to `main` — rejected because it blocks merge feedback, accumulates Hetzner costs proportional to commit frequency, and over-tests the Terraform layer relative to how often it changes.

**Trade-off acknowledged**: A broken `main` Terraform module could go undetected for up to 24 hours. Acceptable for a demo repo; a production repo would add a path-filtered ephemeral test triggered only when `terraform/**` changes.

### Action pins at commit SHA

**Decision**: All third-party GitHub Actions are pinned to full commit SHA (e.g. `actions/checkout@abc1234`). `dependency-review` workflow audits new actions on PRs.

**Rationale**: Tag-based pins (`@v4`) are mutable and have been the vector for supply-chain attacks. SHA pins combined with `dependency-review` give a reproducible and auditable action graph.

### Workflow concurrency cancellation on PRs

**Decision**: `pr-validation` and `smoke-test` use `concurrency: cancel-in-progress: true` per PR/branch.

**Rationale**: Redundant runs waste Hetzner credits and runner minutes. Cancelling superseded runs keeps feedback loops tight.

### Terraform state backend: local with artifact upload

**Decision**: For the smoke-test, Terraform state is stored locally within the runner and uploaded as a GitHub Actions artifact (TTL: 7 days). For the `deploy` workflow, a Hetzner Object Storage (S3-compatible) backend is used.

**Rationale**: Remote state (Terraform Cloud) requires a paid plan or self-hosted instance. Hetzner Object Storage is €0.0059/GB-mo — negligible. This avoids a circular dependency (need the cluster to store state for the cluster).

**Alternative considered**: GitHub-encrypted artifact as state store — rejected because concurrent runs can corrupt state.

## Risks / Trade-offs

- [Hetzner API rate limiting] → Mitigation: smoke-test uses `retry` on `hcloud` API calls; destroy step runs with `continue-on-error: false` but with a timeout to avoid orphaned resources.
- [Orphaned Hetzner resources on runner crash] → Mitigation: destroy step is in a `finally`-equivalent `if: always()` job; a weekly cleanup cron job lists and destroys untagged CI servers older than 24h.
- [HCLOUD_TOKEN secret exposure] → Mitigation: token is scoped to a dedicated CI project in Hetzner with minimum permissions (read server, create/delete server); never printed in logs.
- [Smoke-test cost creep] → Mitigation: CX22 instances are destroyed at end of every run; GitHub Actions concurrency cancellation prevents parallel runs accumulating resources.
- [Terraform plan noise on unrelated changes] → Mitigation: `pr-validation` runs `terraform plan` only on paths that changed (`paths` filter on the workflow trigger).

## Migration Plan

1. Add GitHub secrets (`HCLOUD_TOKEN`, `SSH_PRIVATE_KEY`) to the repo.
2. Create Hetzner Object Storage bucket for Terraform state (`terraform-state-ai-infra`).
3. Merge workflow files — `pr-validation` activates immediately on next PR.
4. Merge `smoke-test` — activates on next push to `main`.
5. Trigger the first manual `deploy` run and verify end-to-end.
6. Add runbook docs and link from main README.

Rollback: disable individual workflows via GitHub UI; no infrastructure is created until `deploy` runs explicitly.

## Open Questions

- Should `infra-smoke-test` also trigger on `terraform/**` path changes in PRs (in addition to the daily cron), to catch Terraform regressions before they land in `main`? Deferred — adds complexity and PR latency; revisit if daily feedback proves too slow.
- Should the deploy workflow target a named cluster environment (GitHub Environments + protection rules)? Deferred — useful for multi-environment setup in a future iteration.
