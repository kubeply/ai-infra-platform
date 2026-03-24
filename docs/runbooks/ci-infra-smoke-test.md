# Runbook: Infra Smoke Test

**Workflow file:** `.github/workflows/infra-smoke-test.yaml`
**Trigger:** Daily cron at 03:00 UTC (04:00 CET), or manual via `workflow_dispatch`

---

## What it does

Full Layer 1 validation cycle — creates a real Hetzner cluster, verifies it, then destroys it.

| Job | Depends on | Purpose |
|---|---|---|
| `provision` | — | `terraform apply` on a fresh Hetzner CX23, uploads kubeconfig artifact |
| `bootstrap` | `provision` | Runs `script/bootstrap-cluster.sh` (installs ArgoCD, applies kustomization) |
| `verify` | `bootstrap` | Runs `script/verify-platform.sh` (asserts cluster + platform health) |
| `destroy` | all (always) | `terraform destroy` — runs even when earlier jobs fail |

Expected end-to-end runtime: **10–20 minutes**.

---

## Monitoring daily runs

Navigate to **Actions → infra-smoke-test** in GitHub.

- Green check: all four jobs passed.
- Red X on `provision`: Terraform failed to create the cluster — check Hetzner API quotas or token validity.
- Red X on `bootstrap`/`verify`: cluster provisioned but platform setup failed — check script output.
- Red X on `destroy`: cleanup failed — see "Orphaned resources" section below.

---

## Manually triggering

**GitHub UI:** Actions → infra-smoke-test → Run workflow → Run workflow

**CLI:**

```sh
gh workflow run infra-smoke-test.yaml
```

The workflow defaults to `hel1` for smoke-test runs. Override it with the
repository variable `SMOKE_TEST_LOCATION` if Hetzner capacity changes.

---

## Checking for orphaned Hetzner resources

If a run crashes before `destroy` completes, resources may be left behind.

**Automated check:**

```sh
hcloud server list --selector "ci=smoke"
```

**Manual check:**

1. Open [Hetzner Cloud Console](https://console.hetzner.cloud/) → Servers
2. Look for servers named `ci-smoke-<run-id>` (e.g. `ci-smoke-1234567890`)
3. Delete any orphaned server and its associated SSH key

**State file:**

Each smoke test uses a unique state key `ci-smoke-<run-id>/terraform.tfstate` in the
`terraform-state-ai-infra` Object Storage bucket. Delete orphaned state keys after
manually removing the server.

---

## What to do if `destroy` fails

1. Note the cluster name from the failing run logs: `ci-smoke-<run-id>`
2. Destroy manually:

```sh
export HCLOUD_TOKEN=<your-token>
export AWS_ACCESS_KEY_ID=<hz-access-key>
export AWS_SECRET_ACCESS_KEY=<hz-secret-key>

cd terraform/modules/hetzner-k3s
terraform init \
  -backend-config="key=ci-smoke-<run-id>/terraform.tfstate"
terraform destroy -auto-approve \
  -var="cluster_name=ci-smoke-<run-id>" \
  -var="location=hel1" \
  -var="ssh_public_key=placeholder" \
  -var="ssh_private_key_path=~/.ssh/ci_key"
```

3. Alternatively, delete directly via `hcloud` CLI:

```sh
hcloud server delete ci-smoke-<run-id>
hcloud ssh-key delete ci-smoke-<run-id>-key
```

---

## Secrets required by this workflow

| Secret | Used by |
|---|---|
| `HCLOUD_TOKEN` | `provision`, `destroy` |
| `SSH_PRIVATE_KEY` | `provision`, `bootstrap`, `destroy` |
| `SSH_PUBLIC_KEY` | `provision` |
| `HZ_OBJECT_STORAGE_ACCESS_KEY` | `provision`, `destroy` (backend) |
| `HZ_OBJECT_STORAGE_SECRET_KEY` | `provision`, `destroy` (backend) |

See [ci-secrets.md](./ci-secrets.md) for setup instructions.
