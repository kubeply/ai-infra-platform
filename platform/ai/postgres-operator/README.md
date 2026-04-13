---
# CloudNativePG PostgreSQL

This optional module installs CloudNativePG for PostgreSQL clusters and the
Barman Cloud plugin for PostgreSQL-native backups.

Pinned versions:

| Component | Chart | App |
|-----------|-------|-----|
| CloudNativePG operator | `cloudnative-pg` `0.28.0` | `1.29.0` |
| Barman Cloud plugin | `plugin-barman-cloud` `0.5.0` | `v0.11.0` |

## Enable The Operator

Add the module from a cluster-specific kustomization when PostgreSQL is needed:

```yaml
resources:
  - ../../platform/ai/postgres-operator
```

The public `clusters/acme` baseline does not include this module and does not
create any PostgreSQL clusters by default.

## Self-Service Contract

Client-specific repositories or private overlays request PostgreSQL capacity by
adding CloudNativePG resources to their own cluster entrypoint:

| Resource | Purpose |
|----------|---------|
| `Cluster` | Creates the PostgreSQL workload, services, generated secrets, and storage |
| `Database` | Creates additional logical databases in an existing cluster |
| `Cluster.spec.managed.roles` | Creates access roles without manual SQL |
| `Pooler` | Creates a PgBouncer endpoint for application traffic |
| `ObjectStore` | Defines the PostgreSQL backup destination and credentials |
| `ScheduledBackup` | Runs PostgreSQL-native backups |

The example manifests in `examples/` are templates. Copy them into a
client-specific entrypoint and replace names, sizes, storage classes, object
storage endpoints, and secret references there.

## Connection Secrets

CloudNativePG creates connection secrets for the bootstrap application user. For
a cluster named `app-postgres` with bootstrap owner `app`, workloads consume
the generated `app-postgres-app` Secret.

Expected workload-facing keys:

| Key | Meaning |
|-----|---------|
| `username` | PostgreSQL role name |
| `password` | PostgreSQL role password |
| `host` | Read/write service DNS name |
| `port` | PostgreSQL service port |
| `dbname` | Bootstrap database name |
| `uri` | PostgreSQL connection URI |
| `jdbc-uri` | JDBC connection URI |

Additional managed roles should receive credentials through generated or
externally synced Secrets. Do not commit literal database passwords to git.

## Tenancy Guidance

Use a dedicated PostgreSQL cluster for production workloads that need isolated
upgrades, restore windows, performance tuning, or backup policy. This is the
default recommendation for critical customer data.

Use multiple logical databases in one PostgreSQL cluster only for related
workloads that deliberately share lifecycle, restore boundaries, and resource
limits. This lowers cost and operational overhead but increases blast radius.

## Backup And Restore

Use the Barman Cloud plugin and `ObjectStore` resources for PostgreSQL data.
Velero can still protect Kubernetes resource definitions and volumes, but it is
not the primary recovery mechanism for database contents.

Backup credentials and destination buckets belong in private overlays,
generated Secrets, or client-specific repositories. The public example uses an
`ExternalSecret` shape to show the expected Secret keys without storing values.
Use the same S3-compatible object storage pattern as the shared storage module
where practical, but keep bucket names and credentials client-specific.

Restore path:

1. Confirm the target object store Secret and `ObjectStore` exist.
2. Copy `examples/restore-cluster.yaml` into the client-specific entrypoint.
3. Set `serverName` to the source cluster archive name.
4. Apply through GitOps and wait for the restored cluster to become ready.
5. Move workloads to the restored cluster after application-level validation.
