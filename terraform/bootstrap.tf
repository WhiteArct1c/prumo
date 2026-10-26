resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "10.11.6"
  create_namespace = true
  wait             = true
  timeout          = 900

  values = [
    file("${path.module}/../platform/argocd-values.yaml"),
  ]

  depends_on = [kind_cluster.prumo]
}

resource "helm_release" "root" {
  name      = "prumo-root"
  namespace = "argocd"
  chart     = "${path.module}/../platform/root"
  wait      = true
  timeout   = 300

  depends_on = [
    helm_release.argocd,
    kubernetes_service.git,
    kubernetes_secret.grafana_admin,
    terraform_data.load_image,
  ]
}
