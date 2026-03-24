# Authentication: set HCLOUD_TOKEN environment variable.
# The hcloud provider reads it automatically — no credentials in tfvars.

locals {
  # Prepend the version env var only when a specific version is requested.
  k3s_install_env = var.k3s_version != "" ? "INSTALL_K3S_VERSION=${var.k3s_version} " : ""
}

resource "hcloud_ssh_key" "k3s" {
  name       = "${var.cluster_name}-key"
  public_key = var.ssh_public_key
}

resource "hcloud_server" "k3s" {
  name        = var.cluster_name
  server_type = var.server_type
  location    = var.location
  image       = "ubuntu-24.04"
  ssh_keys    = [hcloud_ssh_key.k3s.id]

  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail

    # Wait for apt lock and install curl
    until apt-get update -qq 2>/dev/null; do sleep 5; done
    apt-get install -yq curl

    # Fetch the server's public IP from the Hetzner metadata service.
    # This is used as --tls-san so the kubeconfig is valid for remote kubectl access.
    PUBLIC_IP=$(curl -sf http://169.254.169.254/hetzner/v1/metadata/public-ipv4)

    # Install k3s. Disable the bundled Traefik add-on so ArgoCD can manage a
    # pinned Traefik release without conflicting with the k3s default.
    # The TLS SAN ensures the API server cert covers the public IP, making the
    # output kubeconfig usable without certificate errors.
    ${local.k3s_install_env}curl -sfL https://get.k3s.io | \
      INSTALL_K3S_EXEC="server --disable=traefik --tls-san $${PUBLIC_IP}" sh -
  EOF
}

# Block until k3s reports a Ready node before we attempt to read the kubeconfig.
resource "null_resource" "k3s_ready" {
  depends_on = [hcloud_server.k3s]

  triggers = {
    server_id = hcloud_server.k3s.id
  }

  connection {
    type        = "ssh"
    host        = hcloud_server.k3s.ipv4_address
    user        = "root"
    private_key = file(pathexpand(var.ssh_private_key_path))
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "until systemctl is-active --quiet k3s; do echo 'waiting for k3s service...'; sleep 10; done",
      "until /usr/local/bin/kubectl get nodes 2>/dev/null | grep -q ' Ready'; do echo 'waiting for node Ready...'; sleep 10; done",
      "echo 'k3s cluster is ready'"
    ]
  }
}

# Fetch the kubeconfig from the server after k3s is ready.
# Replaces the loopback address with the server's public IP so the config
# is usable from outside the server without any post-processing.
data "external" "kubeconfig" {
  depends_on = [null_resource.k3s_ready]

  program = [
    "${path.module}/scripts/fetch-kubeconfig.sh",
    hcloud_server.k3s.ipv4_address,
    pathexpand(var.ssh_private_key_path),
  ]
}
