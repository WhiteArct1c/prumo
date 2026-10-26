data "sops_file" "grafana" {
  source_file = "${path.module}/../platform/secrets/grafana-admin.yaml"
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      "app.kubernetes.io/part-of" = "prumo"
    }
  }

  depends_on = [kind_cluster.prumo]
}

resource "kubernetes_secret" "grafana_admin" {
  metadata {
    name      = "grafana-admin"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  type = "Opaque"

  data = {
    admin-user     = data.sops_file.grafana.data["stringData.admin-user"]
    admin-password = data.sops_file.grafana.data["stringData.admin-password"]
  }
}
