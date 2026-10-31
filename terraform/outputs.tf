output "cluster_name" {
  description = "kind cluster name."
  value       = kind_cluster.prumo.name
}

output "kubeconfig_path" {
  description = "kubeconfig for this cluster."
  value       = kind_cluster.prumo.kubeconfig_path
}

output "argocd_url" {
  description = "Argo CD UI, after ingress-nginx syncs."
  value       = "http://argocd.prumo.test:8080"
}

output "grafana_url" {
  description = "Grafana, after kube-prometheus-stack syncs."
  value       = "http://grafana.prumo.test:8080"
}
