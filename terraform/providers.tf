terraform {
  required_version = ">= 1.6.0"

  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "0.11.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.36"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
    sops = {
      source  = "carlpett/sops"
      version = "~> 1.2"
    }
  }
}

provider "kind" {}

provider "kubernetes" {
  host                   = kind_cluster.prumo.endpoint
  client_certificate     = kind_cluster.prumo.client_certificate
  client_key             = kind_cluster.prumo.client_key
  cluster_ca_certificate = kind_cluster.prumo.cluster_ca_certificate
}

provider "helm" {
  kubernetes {
    host                   = kind_cluster.prumo.endpoint
    client_certificate     = kind_cluster.prumo.client_certificate
    client_key             = kind_cluster.prumo.client_key
    cluster_ca_certificate = kind_cluster.prumo.cluster_ca_certificate
  }
}

provider "sops" {}
