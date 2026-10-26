variable "cluster_name" {
  type        = string
  description = "Nome do cluster kind."
  default     = "prumo"
}

variable "repo_host_path" {
  type        = string
  description = "Caminho absoluto do repositório na máquina. O kind monta essa pasta no nó para o git daemon."
}

variable "app_image" {
  type        = string
  description = "Imagem do workload de referência já construída localmente. O Terraform carrega essa imagem no cluster."
}

variable "kubeconfig_path" {
  type        = string
  description = "Arquivo kubeconfig escrito pelo kind. Fica fora do Git."
}
