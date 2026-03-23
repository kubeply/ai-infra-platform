# Runbook: Live Deploy

**Workflow file:** `.github/workflows/live-deploy.yaml`
**Trigger:** Every push to `main`

---

## What it does

Deploys platform changes (Layers 2–4: clusters, platform, apps) to the permanent live demo cluster by
triggering an ArgoCD sync. No Terraform is involved — Terraform is exercised separately by the
`infra-smoke-test` workflow.

| Step | Purpose |
|---|---|
| Validate kubeconfig | Fails immediately if `LIVE_CLUSTER_KUBECONFIG` is not set |
| Write kubeconfig | Decodes the secret to `/tmp/kubeconfig` (mode 600) |
| Install ArgoCD CLI | Downloads the pinned ArgoCD CLI binary |
| Sync all Applications | `argocd app sync --all --wait --timeout 300` |
| Rollback (on failure) | Detects degraded Applications and rolls each back to the last healthy revision |
| Remove kubeconfig | Deletes `/tmp/kubeconfig` — always runs, even on failure |

Expected runtime: **1–3 minutes** (sync) + up to 5 minutes for health checks.

---

## How ArgoCD sync works

The `sync` step runs:

```sh
argocd app sync --all --wait --timeout 300 \
  --port-forward --port-forward-namespace argocd
```

- `--all` syncs every Application registered with the ArgoCD instance.
- `--wait` blocks until all Applications reach `Synced` + `Healthy` (or timeout).
- `--timeout 300` — if any Application is not Healthy within 5 minutes the step fails.
- `--port-forward` — connects to ArgoCD via a `kubectl port-forward` tunnel rather than a public URL.

On success the workflow exits 0 and the cluster is up to date.

---

## How automatic rollback works

If the sync step exits non-zero, the rollback step runs (`if: failure()`):

1. Lists all Applications via `argocd app list -o json`.
2. Filters for Applications in `Degraded` health state.
3. Runs `argocd app rollback <app>` for each degraded Application.

ArgoCD rollback reverts the Application to the last known-good revision stored in its history.
After rollback the workflow exits non-zero — the deploy failed, but the cluster is stable again.

---

## Manually re-triggering

After fixing the commit that caused the failure, push or merge to `main` to trigger a new run automatically.

To trigger without a new commit:

**GitHub UI:** Actions → live-deploy → Re-run all jobs

**CLI:**

```sh
gh workflow run live-deploy.yaml
```

---

## Recovery: rollback also fails

If the rollback step itself exits non-zero, the cluster is in an unknown state and requires manual
intervention.

### Step 1 — check Application status

```sh
export KUBECONFIG=~/.kube/live-cluster.yaml
argocd app list
```

Identify which Application is `Degraded`.

### Step 2 — inspect the Application

```sh
argocd app get <app-name> --show-operation
```

Look at the `Message` field under `Operation State` for the root cause.

### Step 3 — manual rollback

```sh
# Roll back to a specific revision (list history first)
argocd app history <app-name>
argocd app rollback <app-name> <revision-id>
```

### Step 4 — hard reset (last resort)

If rollback is not available (e.g. the repository itself is broken):

```sh
# Force-sync from a known-good commit
argocd app set <app-name> --revision <good-commit-sha>
argocd app sync <app-name> --force
```

### Step 5 — re-enable auto-sync

After manually stabilising the cluster, re-enable auto-sync if it was disabled:

```sh
argocd app set <app-name> --sync-policy automated
```

---

## Secrets required by this workflow

| Secret | Used by |
|---|---|
| `LIVE_CLUSTER_KUBECONFIG` | All steps (cluster access) |

See [ci-secrets.md](./ci-secrets.md) for setup instructions.
