---
# Redis-Compatible Valkey

This optional module installs the OT Redis Operator for Redis-compatible
workloads. Client-specific repositories or private overlays declare the actual
Redis-compatible instances.

Pinned versions:

| Component | Chart | App |
|-----------|-------|-----|
| OT Redis Operator | `redis-operator` `0.24.0` | `0.24.0` |
| Default server image | `valkey/valkey:9.0.3` | Valkey `9.0.3` |

Valkey is the default server image family because it is Redis-compatible,
community-governed, and available under the BSD 3-Clause open source license.
This module does not default to Redis Inc. source-available server images.

## Enable The Operator

Add the module from a cluster-specific kustomization when Redis-compatible
capacity is needed:

```yaml
resources:
  - ../../platform/storage/redis
```

The public `clusters/acme` baseline does not include this module and does not
create Redis-compatible instances by default.

## Self-Service Contract

Client-specific repositories or private overlays request Redis-compatible
capacity by adding operator resources to their own cluster entrypoint:

| Resource | Purpose |
|----------|---------|
| `Redis` | Creates one standalone Redis-compatible Valkey service |
| `RedisReplication` | Creates a replicated Redis-compatible Valkey service |
| `ExternalSecret` or generated `Secret` | Supplies password and workload connection data |
| `storage.volumeClaimTemplate` | Enables persistent volumes for durable modes |

The example manifests in `examples/` are templates. Copy the relevant shape
into a client-specific entrypoint and replace names, sizes, storage classes,
secret references, and service names there.

## Modes

Use ephemeral cache mode for disposable cache, queue, rate-limit, or session
data that can be rebuilt. Omit `spec.storage`, set bounded memory, and do not
promise restore of cache contents.

Use persistent standalone mode when a workload needs local persistence and can
accept a single primary. Add `spec.storage.volumeClaimTemplate` and retain PVCs
on deletion. Validate restore on a disposable cluster before treating the data
as durable application state.

Use replicated mode when a workload needs higher availability than a standalone
instance. `RedisReplication` creates multiple Valkey pods and exposes operator
status for the current primary. Client behavior during failover still needs an
application-level smoke test before production use.

Redis Cluster remains a later scale-out path for this module.

## Connection Secrets

Workloads should consume a Kubernetes Secret owned by the client entrypoint.
The examples use `ExternalSecret` to avoid committing literal passwords.

Expected workload-facing keys:

| Key | Meaning |
|-----|---------|
| `host` | Service DNS name |
| `port` | Redis-compatible service port, normally `6379` |
| `username` | Redis ACL username, normally `default` for simple deployments |
| `password` | Password referenced by `spec.kubernetesConfig.redisSecret` |
| `tlsEnabled` | `true` or `false` |
| `ca.crt` | Optional CA bundle when TLS is enabled |

For a standalone resource named `app-cache` in namespace `demo-redis`, the
default service endpoint is `app-cache.demo-redis.svc.cluster.local:6379`.

## Backup And Restore

Velero protects the Kubernetes resource definitions, generated connection
Secrets, and persistent volumes that remain eligible for the generic cluster
backup path. Do not add `velero.io/exclude-from-backup: "true"` to Redis
operator resources, Redis-compatible instance resources, connection Secrets,
or PVCs unless the exclusion and recovery trade-off are documented.

Ephemeral cache contents are disposable. Persistent and replicated modes depend
on Valkey persistence and restored volumes, so a restore drill is required
before using Redis-compatible storage as durable application state. Velero
resource restore is necessary for this platform path, but it is not by itself a
complete Redis application-state recovery guarantee.

## TLS

The operator supports TLS by referencing a Secret through `spec.TLS`. Keep TLS
certificates and private keys in private overlays, generated Secrets, or
provider-backed secret stores. When TLS is enabled, set `tlsEnabled: "true"` in
the workload connection Secret and include the CA material expected by clients.
