## Why

The platform has no infrastructure provisioning layer yet. Layer 1 establishes the Terraform foundation that creates Kubernetes clusters on cloud providers and outputs the kubeconfig consumed by the GitOps bootstrap (Layer 2). Without it, nothing else in the stack can be deployed.

## What Changes

- New `terraform/modules/hetzner-k3s/` — single-node k3s cluster on Hetzner CX22 (€3.29/mo), authenticated via `HCLOUD_TOKEN`, outputs kubeconfig
- New `terraform/modules/shared/dns/` — Cloudflare DNS zone management, shared across cluster targets
- New `terraform/modules/shared/storage/` — S3-compatible bucket used by Loki (log retention) and Velero (cluster backups)
- New `terraform/examples/hetzner-k3s.tfvars.example` — reference config showing required inputs (token, domain, region)

## Capabilities

### New Capabilities

- `hetzner-k3s-cluster`: Provisions a single-node k3s cluster on Hetzner CX22 via the Hetzner Cloud API; outputs kubeconfig for downstream GitOps bootstrap
- `shared-dns`: Manages a Cloudflare DNS zone shared across cluster environments; outputs zone ID and nameservers
- `shared-storage`: Provisions an S3-compatible object storage bucket for platform data (Loki logs, Velero backups); outputs bucket name and credentials

### Modified Capabilities

<!-- No existing specs — this is the first change -->

## Impact

- Creates the entire `terraform/` directory tree (new — no existing code affected)
- Downstream: `clusters/` bootstrap scripts will consume the kubeconfig output from `hetzner-k3s-cluster`
- CI smoke test (`smoke-test.yaml`) will eventually run `terraform apply` against this module on every push to `main` using a real Hetzner CX22
- No impact on `platform/`, `apps/`, or `script/` layers — those are out of scope for this change
