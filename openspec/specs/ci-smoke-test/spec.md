# ci-smoke-test Specification

## Purpose
TBD - created by archiving change github-actions-cicd. Update Purpose after archive.
## Requirements
### Requirement: Infra smoke test runs on a daily schedule
The workflow SHALL be triggered by a cron schedule at **03:00 UTC (04:00 CET)** every day, not on push to `main`. Its sole purpose is validating the Layer 1 Terraform provisioning code on a real Hetzner cluster.

#### Scenario: Daily cron fires at 03:00 UTC
- **WHEN** the scheduled cron trigger fires at 03:00 UTC
- **THEN** the workflow SHALL start a full provision → bootstrap → verify → destroy cycle on an ephemeral Hetzner CX22 cluster

#### Scenario: Push to main does not trigger infra smoke test
- **WHEN** a commit is pushed to `main`
- **THEN** the infra smoke test workflow SHALL NOT be triggered (only `live-deploy` runs on push to `main`)

### Requirement: Smoke test provisions a real Hetzner cluster
The workflow SHALL run `terraform apply` against the Hetzner Layer 1 module using the `HCLOUD_TOKEN` secret, creating a CX22 k3s cluster for the duration of the test run.

#### Scenario: Terraform apply succeeds
- **WHEN** the infra smoke test workflow runs
- **THEN** `terraform apply -auto-approve` SHALL complete without error and output a valid kubeconfig

#### Scenario: Terraform apply fails
- **WHEN** `terraform apply` fails (e.g., API error, quota exceeded)
- **THEN** the workflow SHALL fail immediately and the destroy job SHALL still run via `if: always()`

### Requirement: Core platform modules are deployed after provisioning
The workflow SHALL invoke `script/bootstrap-cluster.sh` after the cluster is ready, deploying the core platform modules (ArgoCD, cert-manager, ingress-nginx) as defined in the target cluster's `kustomization.yaml`.

#### Scenario: Bootstrap completes successfully
- **WHEN** the cluster is up and `bootstrap-cluster.sh` is executed
- **THEN** all core ArgoCD Applications SHALL reach `Synced` and `Healthy` status within the configured timeout

#### Scenario: Bootstrap times out
- **WHEN** an ArgoCD Application does not become healthy within the timeout
- **THEN** the bootstrap step SHALL fail with a descriptive error and the destroy job SHALL run

### Requirement: Platform verification is run against the provisioned cluster
The workflow SHALL execute `script/verify-platform.sh` against the provisioned cluster, checking that all expected pods are running, services are reachable, and health endpoints respond correctly.

#### Scenario: All platform checks pass
- **WHEN** `verify-platform.sh` is executed against a healthy cluster
- **THEN** all assertions SHALL pass and the script SHALL exit 0

#### Scenario: A platform check fails
- **WHEN** `verify-platform.sh` detects a failing pod or unreachable service
- **THEN** the script SHALL exit non-zero, the workflow step SHALL fail, and the destroy job SHALL still run

### Requirement: Cluster is destroyed after every run regardless of outcome
The workflow SHALL include a destroy job that always runs (via `if: always()`) after the test jobs, executing `terraform destroy -auto-approve` to prevent orphaned Hetzner resources.

#### Scenario: Destroy runs after successful test
- **WHEN** the smoke test completes successfully
- **THEN** the destroy job SHALL execute `terraform destroy -auto-approve` and remove all provisioned resources

#### Scenario: Destroy runs after failed test
- **WHEN** any smoke test step fails
- **THEN** the destroy job SHALL still execute via `if: always()` and attempt to remove all provisioned resources

### Requirement: Smoke test state is stored in Hetzner Object Storage
The workflow SHALL configure the Terraform backend to use a Hetzner S3-compatible Object Storage bucket (`terraform-state-ai-infra`) for state, ensuring the destroy job can find the state created by the apply job.

#### Scenario: State is accessible between apply and destroy jobs
- **WHEN** the destroy job runs in a separate GitHub Actions job from the apply job
- **THEN** it SHALL read the Terraform state from Hetzner Object Storage and destroy exactly the resources created by the apply job

