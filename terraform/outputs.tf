output "cluster_name" {
  description = "Nome do cluster kind."
  value       = kind_cluster.prumo.name
}

output "kubeconfig_path" {
  description = "Kubeconfig deste cluster."
  value       = kind_cluster.prumo.kubeconfig_path
}

output "argocd_url" {
  description = "Interface do Argo CD, depois que o ingress-nginx sincronizar."
  value       = "http://argocd.prumo.test:8080"
}

output "grafana_url" {
  description = "Grafana, depois que o kube-prometheus-stack sincronizar."
  value       = "http://grafana.prumo.test:8080"
}
