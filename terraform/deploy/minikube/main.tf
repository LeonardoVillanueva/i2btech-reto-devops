# deploy/minikube/main.tf
# Entorno de despliegue: Minikube local
# Invoca el módulo basicservice con configuración específica para Minikube

terraform {
  required_version = ">= 1.0"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }
}

provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_path
  }
}

module "basicservice" {
  source = "../../modules/basicservice"

  chart_path       = var.chart_path
  namespace        = var.namespace
  htpasswd_content = var.htpasswd_content
  image_repository = var.image_repository
  image_tag        = var.image_tag
  replica_count    = var.replica_count
  logs_host_path   = var.logs_host_path
  ingress_host     = var.ingress_host
}
