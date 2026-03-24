## Why

The platform has no automated quality gate or deployment pipeline — every change lands in `main` without validation, and provisioning a Hetzner cluster requires manual steps. CI/CD is the credibility signal that this repo is operated, not just installed.

## What Changes

- Add a **pull-request validation workflow** that runs on every PR: Terraform `fmt`/`validate`/`plan`, YAML linting, Kubernetes manifest validation (kubeval/kubeconform), and shell-script linting (shellcheck).
- Add a **smoke-test workflow** that spins up a real Hetzner k3s cluster, deploys core platform modules, runs `verify-platform.sh`, then destroys it — triggered on every push to `main`.
- Add a **deploy workflow** (manually triggered) that applies Layer 1 Terraform and bootstraps the long-lived Hetzner cluster.
- Add a **docs/runbooks** for each workflow describing how to operate, debug, and re-run them.
- Add a **dependency review** workflow that flags new third-party actions or pinned-digest drifts.

## Capabilities

### New Capabilities

- `ci-pr-validation`: Static analysis and validation gate for every pull request — Terraform fmt/validate/plan, YAML lint, Kubernetes manifest validation, shellcheck.
- `ci-live-deploy`: On every push to `main`, deploy platform changes to the live demo cluster via ArgoCD sync; roll back automatically if sync fails.
- `ci-smoke-test`: Daily cron (04:00 CET / 03:00 UTC) — provisions an ephemeral Hetzner CX22, deploys core modules, verifies, destroys. Validates Layer 1 Terraform without blocking merges.
- `ci-deploy`: Controlled deployment workflow for applying Layer 1 Terraform and bootstrapping the long-lived cluster on Hetzner (manual trigger).
- `ci-dependency-review`: Dependency and action-pin auditing on PRs.

### Modified Capabilities

<!-- No existing spec-level capabilities are changing. -->

## Impact

- **`.github/workflows/`**: New workflow files — `pr-validation.yaml`, `smoke-test.yaml`, `deploy.yaml`, `dependency-review.yaml`.
- **`terraform/`**: Consumed by CI for `fmt`, `validate`, and `plan` in `pr-validation`; applied in `deploy`.
- **`script/`**: `bootstrap-cluster.sh` and `verify-platform.sh` invoked by `smoke-test`.
- **`docs/`**: New runbooks — `ci-pr-validation.md`, `ci-smoke-test.md`, `ci-deploy.md`.
- **GitHub secrets**: `HCLOUD_TOKEN` required for smoke-test and deploy; `TF_API_TOKEN` optional for remote state.
- **Cost**: Permanent Hetzner CX22 test node (~€3.29/mo) plus ephemeral cluster costs per smoke-test run (~€0.01/run).
