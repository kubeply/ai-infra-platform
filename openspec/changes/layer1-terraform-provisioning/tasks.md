## 1. Module scaffolding

- [ ] 1.1 Create `terraform/modules/hetzner-k3s/` directory with `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`
- [ ] 1.2 Create `terraform/modules/shared/dns/` directory with `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`
- [ ] 1.3 Create `terraform/modules/shared/storage/` directory with `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`
- [ ] 1.4 Create `terraform/examples/` directory and `hetzner-k3s.tfvars.example` with documented inputs

## 2. hetzner-k3s module

- [ ] 2.1 Declare provider requirements: `hetzner/hcloud` in `versions.tf`
- [ ] 2.2 Implement `variables.tf`: `cluster_name` (string, required), `location` (string, required), `server_type` (string, default `cx22`)
- [ ] 2.3 Implement `main.tf`: `hcloud_server` resource with cloud-init that installs k3s via the official install script
- [ ] 2.4 Implement `outputs.tf`: `kubeconfig` output (sensitive = true) extracted from cloud-init or fetched via SSH post-provision
- [ ] 2.5 Verify `terraform validate` passes in the module directory

## 3. shared/dns module

- [ ] 3.1 Declare provider requirements: `cloudflare/cloudflare` in `versions.tf`
- [ ] 3.2 Implement `variables.tf`: `domain` (string, required)
- [ ] 3.3 Implement `main.tf`: `cloudflare_zone` data source (zone must already exist in Cloudflare account)
- [ ] 3.4 Implement `outputs.tf`: `zone_id` (string)
- [ ] 3.5 Verify `terraform validate` passes in the module directory

## 4. shared/storage module

- [ ] 4.1 Declare provider requirements: `hashicorp/aws` (used for S3-compatible Hetzner Object Storage) in `versions.tf`
- [ ] 4.2 Implement `variables.tf`: `bucket_name` (string, required), `region` (string, default `eu-central-1`)
- [ ] 4.3 Implement `main.tf`: `aws_s3_bucket` resource configured with Hetzner Object Storage endpoint
- [ ] 4.4 Implement `outputs.tf`: `bucket_name` (string), `endpoint` (string)
- [ ] 4.5 Verify `terraform validate` passes in the module directory

## 5. Examples and documentation

- [ ] 5.1 Fill `terraform/examples/hetzner-k3s.tfvars.example` with all required and optional variables, each with an inline comment
- [ ] 5.2 Add a `terraform/modules/hetzner-k3s/README.md` documenting inputs, outputs, and authentication requirements
- [ ] 5.3 Add a `terraform/modules/shared/dns/README.md` documenting inputs, outputs, and `CLOUDFLARE_API_TOKEN` requirement
- [ ] 5.4 Add a `terraform/modules/shared/storage/README.md` documenting inputs, outputs, and S3 credential requirements
