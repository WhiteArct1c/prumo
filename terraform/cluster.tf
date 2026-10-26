resource "kind_cluster" "prumo" {
  name            = var.cluster_name
  wait_for_ready  = true
  kubeconfig_path = var.kubeconfig_path

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"

      extra_port_mappings {
        container_port = 80
        host_port      = 8080
        protocol       = "TCP"
      }

      extra_port_mappings {
        container_port = 443
        host_port      = 8443
        protocol       = "TCP"
      }

      extra_mounts {
        host_path      = var.repo_host_path
        container_path = "/git/prumo"
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
