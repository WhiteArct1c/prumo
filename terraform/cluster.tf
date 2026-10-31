resource "kind_cluster" "prumo" {
  name            = var.cluster_name
  wait_for_ready  = true
  kubeconfig_path = var.kubeconfig_path

  # kind 0.33 defaults to Kubernetes 1.37. That version does not finish
  # kubeadm on Docker Desktop still using cgroup v1. 1.32 starts.
  node_image = "kindest/node:v1.32.2"

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"

      # Without listen_address Docker publishes on 0.0.0.0 and Grafana and
      # Argo CD are open to the local network, with the password in the README.
      extra_port_mappings {
        container_port = 80
        host_port      = 8080
        listen_address = "127.0.0.1"
        protocol       = "TCP"
      }

      extra_port_mappings {
        container_port = 443
        host_port      = 8443
        listen_address = "127.0.0.1"
        protocol       = "TCP"
      }

      # Only .git is mounted. The whole clone folder would also bring in
      # tfstate and the admin kubeconfig, which live outside Git.
      extra_mounts {
        host_path      = "${var.repo_host_path}/.git"
        container_path = "/git/prumo/.git"
        read_only      = true
      }
    }
  }
}

resource "terraform_data" "load_image" {
  triggers_replace = [
    kind_cluster.prumo.id,
    var.app_image,
  ]

  provisioner "local-exec" {
    command = "kind load docker-image ${var.app_image} --name ${kind_cluster.prumo.name}"
  }
}

resource "terraform_data" "load_git_image" {
  triggers_replace = [
    kind_cluster.prumo.id,
    "prumo-git:local",
  ]

  provisioner "local-exec" {
    command = "kind load docker-image prumo-git:local --name ${kind_cluster.prumo.name}"
  }
}
