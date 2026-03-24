## ADDED Requirements

### Requirement: Terraform formatting is enforced
The workflow SHALL run `terraform fmt -check -recursive` on all `.tf` files and fail the PR if any file is not formatted according to canonical Hetzner/Terraform style.

#### Scenario: Unformatted Terraform file in PR
- **WHEN** a pull request modifies a `.tf` file that is not canonically formatted
- **THEN** the `terraform-fmt` step SHALL fail with a non-zero exit code and the PR check is marked failed

#### Scenario: All Terraform files are formatted
- **WHEN** all `.tf` files in the PR diff are canonically formatted
- **THEN** the `terraform-fmt` step SHALL exit 0 and the check passes

### Requirement: Terraform configuration is validated
The workflow SHALL run `terraform validate` for each module directory that contains changed `.tf` files, catching syntax errors and provider misconfigurations without contacting external APIs.

#### Scenario: Invalid Terraform syntax in changed module
- **WHEN** a pull request introduces a syntax error or invalid provider reference in a Terraform module
- **THEN** the `terraform-validate` step SHALL fail and report the offending file and line

#### Scenario: Valid Terraform configuration
- **WHEN** all changed Terraform modules pass `terraform validate`
- **THEN** the check passes and the next step executes

### Requirement: Terraform plan is generated for changed modules
The workflow SHALL run `terraform plan -detailed-exitcode` for each Layer 1 module directory with changed files, using read-only cloud credentials. The plan output SHALL be posted as a PR comment.

#### Scenario: Terraform plan detects a diff
- **WHEN** a pull request would change infrastructure state
- **THEN** a plan summary SHALL be posted as a PR comment showing resource additions, modifications, and deletions

#### Scenario: Terraform plan fails due to missing variable
- **WHEN** a required Terraform variable is not set in CI
- **THEN** the plan step SHALL fail and the error SHALL be visible in the step log

### Requirement: YAML files are linted
The workflow SHALL run `yamllint` with the project's `.yamllint.yaml` config on all changed `.yaml` and `.yml` files, enforcing consistent indentation, quoting, and structure.

#### Scenario: YAML file has trailing spaces
- **WHEN** a pull request introduces a YAML file with trailing whitespace
- **THEN** the `yamllint` step SHALL fail and identify the offending lines

#### Scenario: Valid YAML files
- **WHEN** all changed YAML files conform to `.yamllint.yaml` rules
- **THEN** the `yamllint` step SHALL exit 0

### Requirement: Kubernetes manifests are validated against the target API version
The workflow SHALL run `kubeconform` on all Kubernetes manifest files under `platform/`, `clusters/`, and `apps/` that are modified in the PR, validating them against the k3s-compatible Kubernetes API schema version pinned in the workflow.

#### Scenario: Manifest uses a deprecated API version
- **WHEN** a pull request includes a Kubernetes manifest using a deprecated `apiVersion` (e.g., `networking.k8s.io/v1beta1`)
- **THEN** the `kubeconform` step SHALL fail and identify the resource and file

#### Scenario: All manifests use valid API versions
- **WHEN** all changed Kubernetes manifests conform to the pinned schema version
- **THEN** the `kubeconform` step SHALL exit 0

### Requirement: Shell scripts are linted
The workflow SHALL run `shellcheck` on all changed `.sh` files under `script/` and `.github/`, flagging unreachable code, unquoted variables, and other common shell errors.

#### Scenario: Shell script uses unquoted variable
- **WHEN** a pull request introduces a shell script with an unquoted variable expansion
- **THEN** the `shellcheck` step SHALL fail with a SC2086 (or equivalent) warning

#### Scenario: Shell scripts pass linting
- **WHEN** all changed shell scripts pass `shellcheck` with no errors or warnings
- **THEN** the step SHALL exit 0

### Requirement: PR validation runs only on changed paths
The workflow SHALL use GitHub Actions `paths` filters so that Terraform steps are skipped when only docs or non-Terraform files change, and Kubernetes validation is skipped when only Terraform files change.

#### Scenario: Only docs changed in PR
- **WHEN** a pull request only modifies files under `docs/`
- **THEN** the Terraform and Kubernetes validation jobs SHALL be skipped (not failed)

#### Scenario: Terraform and Kubernetes files both changed
- **WHEN** a pull request modifies both `terraform/` and `platform/` files
- **THEN** both Terraform and Kubernetes validation jobs SHALL execute
