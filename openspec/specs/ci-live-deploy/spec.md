# ci-live-deploy Specification

## Purpose
TBD - created by archiving change github-actions-cicd. Update Purpose after archive.
## Requirements
### Requirement: Live deploy triggers on every push to main
The workflow SHALL trigger on every push to the `main` branch and deploy platform changes (Layers 2-4: clusters, platform, apps) to the live demo cluster by invoking an ArgoCD sync.

#### Scenario: Push to main triggers live deploy
- **WHEN** a commit is merged to `main`
- **THEN** the live-deploy workflow SHALL start within seconds and begin syncing ArgoCD Applications on the live cluster

#### Scenario: Terraform-only push does not skip live deploy
- **WHEN** a push to `main` only modifies `terraform/` files
- **THEN** the live-deploy workflow SHALL still run but the ArgoCD sync SHALL produce no changes (no platform manifests changed)

### Requirement: ArgoCD sync is triggered for all Applications
The workflow SHALL connect to the live cluster using a stored kubeconfig secret and run `argocd app sync --all` (or equivalent), waiting for all Applications to reach `Synced` and `Healthy` status.

#### Scenario: Sync completes successfully
- **WHEN** ArgoCD syncs all Applications after a push to `main`
- **THEN** all Applications SHALL reach `Synced` and `Healthy` within the configured timeout and the workflow SHALL exit 0

#### Scenario: Sync times out
- **WHEN** an Application does not become `Healthy` within the timeout (default: 5 minutes)
- **THEN** the workflow SHALL fail, surface which Application is degraded, and trigger the rollback step

### Requirement: Automatic rollback on sync failure
If the ArgoCD sync fails or any Application becomes `Degraded`, the workflow SHALL automatically trigger an ArgoCD rollback to the previous revision for the affected Application(s).

#### Scenario: Application becomes degraded after sync
- **WHEN** an Application transitions to `Degraded` state after a sync
- **THEN** the workflow SHALL execute `argocd app rollback <app-name>` to revert to the last known good revision

#### Scenario: Rollback succeeds
- **WHEN** the ArgoCD rollback completes and the Application returns to `Healthy`
- **THEN** the workflow SHALL exit with a non-zero code (the deploy failed) but the cluster SHALL be stable again

#### Scenario: Rollback also fails
- **WHEN** the rollback itself fails to restore a healthy state
- **THEN** the workflow SHALL exit non-zero and include a clear message directing the operator to the runbook for manual recovery

### Requirement: Live cluster kubeconfig is stored as a GitHub secret
The workflow SHALL authenticate to the live cluster using a kubeconfig stored as the GitHub secret `LIVE_CLUSTER_KUBECONFIG`. The secret SHALL never be printed in workflow logs.

#### Scenario: Kubeconfig secret is present
- **WHEN** the live-deploy workflow runs
- **THEN** it SHALL decode `LIVE_CLUSTER_KUBECONFIG` to a temp file, use it for all `kubectl` and `argocd` commands, and delete the temp file at the end of the job

#### Scenario: Kubeconfig secret is missing
- **WHEN** `LIVE_CLUSTER_KUBECONFIG` is not set
- **THEN** the workflow SHALL fail immediately with a clear error: "LIVE_CLUSTER_KUBECONFIG secret is not configured"

### Requirement: Live deploy uses concurrency to serialize runs
The workflow SHALL declare a concurrency group scoped to the `main` branch with `cancel-in-progress: false`, so that concurrent pushes are queued rather than cancelled — preventing out-of-order syncs.

#### Scenario: Two pushes to main in rapid succession
- **WHEN** two commits are pushed to `main` before the first live-deploy finishes
- **THEN** the second run SHALL wait in the queue and execute after the first completes, ensuring syncs are applied in commit order

