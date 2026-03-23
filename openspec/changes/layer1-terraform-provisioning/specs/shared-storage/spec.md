## ADDED Requirements

### Requirement: Module provisions an S3-compatible object storage bucket
The `terraform/modules/shared/storage` module SHALL provision a single S3-compatible object storage bucket. For the Hetzner target, this MUST use Hetzner Object Storage (S3-compatible). The bucket name SHALL be an input variable. Credentials MUST come from environment variables (`AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` pointing to the Hetzner Object Storage API key).

#### Scenario: Bucket is created after apply
- **WHEN** `terraform apply` is run with valid credentials and a `bucket_name` input
- **THEN** an S3-compatible bucket is created and the bucket name is available as a Terraform output

#### Scenario: Missing credentials cause pre-flight error
- **WHEN** `AWS_ACCESS_KEY_ID` or `AWS_SECRET_ACCESS_KEY` is not set
- **THEN** `terraform plan` fails with a provider authentication error before any resources are created

### Requirement: Module outputs bucket name and endpoint for downstream use
The module SHALL expose the following outputs: `bucket_name` (string), `endpoint` (string, the S3-compatible endpoint URL). These SHALL be consumable by platform modules (Loki, Velero) to configure their storage backends.

#### Scenario: Outputs are usable by Loki configuration
- **WHEN** a Helm values file for Loki references this module's `bucket_name` and `endpoint` outputs
- **THEN** Loki can write logs to the bucket without additional configuration

#### Scenario: Outputs are usable by Velero configuration
- **WHEN** a BackupStorageLocation manifest for Velero references this module's `bucket_name` and `endpoint` outputs
- **THEN** Velero can store backup archives in the bucket

### Requirement: Module is stand-alone and shared across cluster environments
The storage module SHALL have no dependency on any cluster module. A single bucket SHALL serve multiple clusters (e.g., dev and production) by using different prefixes within the bucket.

#### Scenario: Module applies independently
- **WHEN** `terraform apply` is run in `terraform/modules/shared/storage/` without any other module's state
- **THEN** apply succeeds using only the `bucket_name` input and storage credentials env vars
