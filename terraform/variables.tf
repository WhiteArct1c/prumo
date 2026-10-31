variable "cluster_name" {
  type        = string
  description = "kind cluster name."
  default     = "prumo"
}

variable "repo_host_path" {
  type        = string
  description = "Absolute path of the repository on the host. kind mounts that folder's .git on the node for the git daemon."
}

variable "app_image" {
  type        = string
  description = "Locally built sample workload image. Terraform loads it into the cluster."
}

variable "kubeconfig_path" {
  type        = string
  description = "kubeconfig file written by kind. Stays out of Git."
}
