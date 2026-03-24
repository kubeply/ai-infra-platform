# CI Secrets Reference

All secrets are configured under **Settings → Secrets and variables → Actions** in the GitHub repository.

## Required Secrets

### `HCLOUD_TOKEN`

Hetzner Cloud API token with **Read & Write** permissions.
Used by: `pr-validation` (plan), `infra-smoke-test`, `deploy`.

Create at: <https://console.hetzner.cloud/> → Project → Security → API Tokens.
Scope the token to a dedicated CI project to limit blast radius.

---

### `SSH_PRIVATE_KEY`

ED25519 or RSA private key in PEM format — full contents including the
`-----BEGIN OPENSSH PRIVATE KEY-----` header and footer.
Used by: `infra-smoke-test` (kubeconfig retrieval), `deploy` (kubeconfig retrieval).

Generate a dedicated CI key:

```sh
ssh-keygen -t ed25519 -C "ci@ai-infra-platform" -N "" -f ~/.ssh/ci_key
```

---

### `SSH_PUBLIC_KEY`

The public key counterpart to `SSH_PRIVATE_KEY` (single line, e.g.
`ssh-ed25519 AAAA... ci@ai-infra-platform`).
Used by: `infra-smoke-test`, `deploy` — deployed to the Hetzner server as an authorised key.

This is the content of `~/.ssh/ci_key.pub` from the key generated above.

---

### `HZ_OBJECT_STORAGE_ACCESS_KEY`

Hetzner Object Storage S3-compatible access key.
Used by: every workflow that runs `terraform init` or `terraform apply` (S3 backend auth).

Create at: <https://console.hetzner.cloud/> → Object Storage → Access Keys → Generate key.

---

### `HZ_OBJECT_STORAGE_SECRET_KEY`

Hetzner Object Storage S3-compatible secret key (shown only once at creation).
Used by: same workflows as `HZ_OBJECT_STORAGE_ACCESS_KEY`.

---

### `LIVE_CLUSTER_KUBECONFIG`

Base64-encoded kubeconfig for the permanent live demo cluster.
Used by: `live-deploy` workflow (ArgoCD sync).
_(Not needed until Layer 2 is deployed.)_

If you followed the Hetzner first-deploy runbook, your kubeconfig is typically
stored at `~/.kube/ai-infra-dev.yaml`.

Encode the file:

```sh
base64 -i ~/.kube/ai-infra-dev.yaml | tr -d '\n'
```

If your kubeconfig is stored at a different path, use that file instead. The
secret name stays the same: `LIVE_CLUSTER_KUBECONFIG`.

---

## Optional Repository Variables

Configure under **Settings → Secrets and variables → Actions → Variables**:

| Variable | Default | Description |
|---|---|---|
| `CLUSTER_NAME` | `ai-infra-platform` | Hetzner server name for the `deploy` workflow |
| `CLUSTER_LOCATION` | `hel1` | Hetzner datacenter (e.g. `nbg1`, `fsn1`, `hel1`) |

---

## Pre-flight Checklist

Before running any workflow for the first time:

- [ ] `HCLOUD_TOKEN` is set and scoped to the correct Hetzner project
- [ ] `SSH_PRIVATE_KEY` and `SSH_PUBLIC_KEY` are a matching pair
- [ ] `HZ_OBJECT_STORAGE_ACCESS_KEY` and `HZ_OBJECT_STORAGE_SECRET_KEY` are set
- [ ] Hetzner Object Storage bucket `terraform-state-ai-infra` exists in region `fsn1`
- [ ] GitHub Environment `production` is configured with at least one required reviewer (for `deploy`)
