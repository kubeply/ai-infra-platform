# ci-dependency-review Specification

## Purpose
TBD - created by archiving change github-actions-cicd. Update Purpose after archive.
## Requirements
### Requirement: Third-party GitHub Actions are pinned to commit SHA
All third-party GitHub Actions (not owned by `actions/` or the repo itself) used in any workflow file SHALL be referenced by full commit SHA, not by tag or branch name.

#### Scenario: PR introduces a tag-pinned third-party action
- **WHEN** a pull request adds or modifies a workflow that references a third-party action using a mutable tag (e.g., `some-org/some-action@v2`)
- **THEN** the dependency-review step SHALL fail and report the action that is not SHA-pinned

#### Scenario: All actions are SHA-pinned
- **WHEN** all actions in the workflow files are referenced by full commit SHA
- **THEN** the dependency-review step SHALL pass

### Requirement: New dependencies are reviewed on PRs
The workflow SHALL run the GitHub `actions/dependency-review-action` on every PR, blocking merges that introduce dependencies with known CVEs at severity HIGH or CRITICAL.

#### Scenario: PR introduces a dependency with a known critical CVE
- **WHEN** a pull request adds a dependency (e.g., a new Terraform provider version) that has a known CVE at severity CRITICAL
- **THEN** the dependency-review check SHALL fail and list the affected dependency and CVE

#### Scenario: PR introduces only low-severity dependency changes
- **WHEN** a pull request updates dependencies with no HIGH or CRITICAL CVEs
- **THEN** the dependency-review check SHALL pass

### Requirement: Dependency review runs only on pull requests
The workflow SHALL be triggered exclusively on `pull_request` events (not on push to `main`), using read-only `GITHUB_TOKEN` permissions.

#### Scenario: Push to main does not trigger dependency review
- **WHEN** a commit is pushed directly to `main`
- **THEN** the dependency-review workflow SHALL NOT trigger

#### Scenario: PR triggers dependency review
- **WHEN** a pull request is opened or synchronized
- **THEN** the dependency-review workflow SHALL run with `contents: read` permission only

