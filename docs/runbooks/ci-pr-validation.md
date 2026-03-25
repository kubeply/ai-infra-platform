# Runbook: PR Validation

**Workflow file:** `.github/workflows/pr-validation.yaml`
**Trigger:** Pull request opened, synchronised, or reopened

---

## What it does

A `changes` job detects which paths changed; downstream jobs are skipped automatically
when their paths are unaffected.

| Job | Paths that trigger it | Purpose |
|---|---|---|
| `terraform-fmt` | `terraform/**` | `terraform fmt -check -recursive` |
| `terraform-validate` | `terraform/**` | `terraform validate` per module |
| `terraform-plan` | `terraform/**` | `terraform plan` + posts output as PR comment |
| `yaml-lint` | `**/*.yaml`, `**/*.yml` | `yamllint` with `.yamllint.yaml` config |
| `shellcheck` | `.github/**/*.sh` | Shell script lint |

---

## Reading the plan output

The `terraform-plan` job posts a collapsible PR comment. Open it to see:

- Lines starting with `+` — resources to **add**
- Lines starting with `-` — resources to **destroy**
- Lines starting with `~` — resources to **update in-place**
- Summary line: `Plan: X to add, Y to change, Z to destroy`

Exit code **0** means no changes. Exit code **2** means changes detected — both are
treated as success. Only exit code **1** (error) fails the check.

---

## Re-triggering jobs

Push an empty commit to the PR branch:

```sh
git commit --allow-empty -m "ci: re-trigger" && git push
```

Or close and reopen the PR from the GitHub UI.

---

## Fixing common failures

### `terraform-fmt` fails

```sh
# Run locally and commit the result
terraform fmt -recursive ./terraform
```

### `terraform-validate` fails

```sh
terraform -chdir=terraform/modules/hetzner-k3s init -backend=false
terraform -chdir=terraform/modules/hetzner-k3s validate
```

The error output includes the offending file and line number.

### `terraform-plan` fails with "missing variable" or "no such secret"

Ensure all required GitHub secrets are configured in repository settings.

The plan also requires:
- `HZ_OBJECT_STORAGE_ACCESS_KEY` + `HZ_OBJECT_STORAGE_SECRET_KEY` for backend init
- `HCLOUD_TOKEN` for the Hetzner provider
- `SSH_PUBLIC_KEY` + `SSH_PRIVATE_KEY` for the cluster variables

### `yaml-lint` fails

```sh
pip install yamllint
yamllint -c .yamllint.yaml .
```

Common fixes:
- Remove trailing whitespace
- Use 2-space indentation (not 4, not tabs)
- Quote boolean-looking strings: `"true"` not `true` in YAML values

### `shellcheck` fails

```sh
shellcheck --severity=warning .github/path/to/script.sh
```

Common fixes:
- Quote variable expansions: `"$VAR"` not `$VAR`
- Use `[[ ]]` instead of `[ ]` for conditionals
- Add `set -euo pipefail` at the top of every script

---

## Secrets required by this workflow

| Secret | Used by |
|---|---|
| `HCLOUD_TOKEN` | `terraform-plan` |
| `SSH_PRIVATE_KEY` | `terraform-plan` |
| `SSH_PUBLIC_KEY` | `terraform-plan` |
| `HZ_OBJECT_STORAGE_ACCESS_KEY` | `terraform-plan` (backend) |
| `HZ_OBJECT_STORAGE_SECRET_KEY` | `terraform-plan` (backend) |

Configure the required secrets in repository settings before re-running the workflow.
