resource "kubernetes_namespace" "git" {
  metadata {
    name = "git"
    labels = {
      "app.kubernetes.io/part-of" = "prumo"
    }
  }

  depends_on = [kind_cluster.prumo]
}

resource "kubernetes_deployment" "git" {
  metadata {
    name      = "git"
    namespace = kubernetes_namespace.git.metadata[0].name
    labels = {
      app = "git"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "git"
      }
    }

    template {
      metadata {
        labels = {
          app = "git"
        }
      }

      spec {
        container {
          name              = "git"
          image             = "prumo-git:local"
          image_pull_policy = "IfNotPresent"
          command           = ["git"]
          args = [
            "daemon",
            "--reuseaddr",
            "--base-path=/git",
            "--export-all",
            "--informative-errors",
            "--listen=0.0.0.0",
            "--port=9418",
            "--verbose",
          ]

          port {
            name           = "git"
            container_port = 9418
          }

          readiness_probe {
            tcp_socket {
              port = 9418
            }
            initial_delay_seconds = 2
            period_seconds        = 5
          }

          volume_mount {
            name       = "repo"
            mount_path = "/git/prumo"
            read_only  = true
          }
        }

        volume {
          name = "repo"
          host_path {
            path = "/git/prumo"
            type = "Directory"
          }
        }
      }
    }
  }

  depends_on = [terraform_data.load_git_image]
}

resource "kubernetes_service" "git" {
  metadata {
    name      = "git"
    namespace = kubernetes_namespace.git.metadata[0].name
  }

  spec {
    selector = {
      app = "git"
    }

    port {
      name        = "git"
      port        = 9418
      target_port = 9418
    }
  }
}
