## ADDED Requirements

### Requirement: Module provisions a single-node k3s cluster on Hetzner Cloud
The `terraform/modules/hetzner-k3s` module SHALL provision a single-node Kubernetes cluster running k3s on a Hetzner CX22 server. The module MUST authenticate using the `HCLOUD_TOKEN` environment variable. No credentials SHALL appear in `.tfvars` files or Terraform state in plaintext.

#### Scenario: Successful cluster provisioning
- **WHEN** `terraform apply` is run with a valid `HCLOUD_TOKEN` env var and required inputs (location, cluster_name)
- **THEN** a CX22 server is created in Hetzner Cloud, k3s is installed and running, and `terraform output kubeconfig` returns a valid kubeconfig string

#### Scenario: Missing token causes informative error
- **WHEN** `HCLOUD_TOKEN` is not set in the environment
- **THEN** `terraform plan` fails with a provider authentication error before any resources are created

### Requirement: Module outputs kubeconfig as a sensitive value
The module SHALL expose a `kubeconfig` output of type `string` marked `sensitive = true`. The kubeconfig MUST be valid for use with `kubectl` and `helm` against the provisioned cluster.

#### Scenario: kubeconfig output is usable
- **WHEN** `terraform output -raw kubeconfig` is captured and written to a file
- **THEN** `kubectl --kubeconfig=<file> get nodes` returns the single cluster node in Ready state

#### Scenario: kubeconfig is redacted in plan output
- **WHEN** `terraform plan` or `terraform apply` is run
- **THEN** the kubeconfig value is shown as `(sensitive value)` in terminal output

### Requirement: Module accepts documented, non-secret inputs via tfvars
The module SHALL declare the following input variables: `cluster_name` (string), `location` (string, e.g. `nbg1`), `server_type` (string, default `cx22`). A `terraform/examples/hetzner-k3s.tfvars.example` file SHALL document all required and optional inputs with comments.

#### Scenario: Defaults allow minimal configuration
- **WHEN** only `cluster_name` and `location` are provided in tfvars
- **THEN** `terraform plan` succeeds using the default `cx22` server type

#### Scenario: Example file is self-documenting
- **WHEN** a user opens `terraform/examples/hetzner-k3s.tfvars.example`
- **THEN** every variable is present with a comment explaining its purpose and example value

### Requirement: Module is destroyed cleanly with terraform destroy
All resources created by the module SHALL be tracked in Terraform state. Running `terraform destroy` SHALL remove the server and any associated resources without manual cleanup.

#### Scenario: Clean teardown
- **WHEN** `terraform destroy` is run after a successful apply
- **THEN** the Hetzner Cloud server is deleted and the state file contains no remaining resources
