## ADDED Requirements

### Requirement: Module manages a Cloudflare DNS zone
The `terraform/modules/shared/dns` module SHALL manage a Cloudflare DNS zone using the Cloudflare Terraform provider. Authentication MUST use the `CLOUDFLARE_API_TOKEN` environment variable. The zone itself (the domain) SHALL be an input variable — the module does not register domains.

#### Scenario: Zone is managed after apply
- **WHEN** `terraform apply` is run with a valid `CLOUDFLARE_API_TOKEN` and `domain` input
- **THEN** the Cloudflare zone for that domain is present in state and the zone ID is available as a Terraform output

#### Scenario: Missing API token causes pre-flight error
- **WHEN** `CLOUDFLARE_API_TOKEN` is not set
- **THEN** `terraform plan` fails with a provider authentication error before any API calls are made

### Requirement: Module outputs zone ID for use by other modules
The module SHALL expose a `zone_id` output of type `string`. This output SHALL be consumable by other Terraform modules or by the bootstrap script to create DNS records for platform services.

#### Scenario: zone_id output is usable downstream
- **WHEN** another Terraform configuration references this module's `zone_id` output
- **THEN** the value can be passed to the Cloudflare provider's `cloudflare_record` resource without error

### Requirement: Module is stand-alone and not coupled to any cluster module
The DNS module SHALL have no dependency on `hetzner-k3s` or any other cluster module. It SHALL be applied once per account/domain, not once per cluster.

#### Scenario: Module applies independently
- **WHEN** `terraform apply` is run in `terraform/modules/shared/dns/` without any other module's state
- **THEN** apply succeeds using only the `domain` input and `CLOUDFLARE_API_TOKEN` env var
