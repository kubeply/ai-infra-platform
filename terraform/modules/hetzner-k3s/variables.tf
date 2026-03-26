variable "cluster_name" {
  type        = string
  description = "Name for the k3s cluster and the Hetzner server."
}

variable "location" {
  type        = string
  description = "Hetzner datacenter location (e.g. nbg1, fsn1, hel1)."
}

variable "server_type" {
  type        = string
  default     = "cx33"
  description = "Hetzner server type. CX33 (4 vCPU, 8 GB RAM) is the default — suitable for demo and platform workloads."
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key content (e.g. contents of ~/.ssh/id_rsa.pub). Deployed to the server to allow post-provision access."
}

variable "ssh_private_key_path" {
  type        = string
  default     = "~/.ssh/id_rsa"
  description = "Path to the SSH private key on the local machine. Used to retrieve the kubeconfig after provisioning."
}

variable "k3s_version" {
  type        = string
  default     = ""
  description = "k3s version to install (e.g. v1.29.2+k3s1). Leave empty to install the latest stable release."
}
