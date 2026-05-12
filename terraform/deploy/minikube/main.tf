# deploy/minikube/main.tf
# Entorno de despliegue: Minikube local
# Crea el namespace y despliega basicservice via Helm

terraform {
  required_version = ">= 1.0"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "kubernetes" {
  config_path = var.kubeconfig_path
}

provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_path
  }
}

# Crear namespace dedicado para la aplicacion
resource "kubernetes_namespace" "basicservice" {
  metadata {
    name = var.namespace
    labels = {
      app        = "basicservice"
      managed-by = "terraform"
    }
  }
}

# Generar certificado TLS autofirmado para el Ingress
resource "tls_private_key" "ingress" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "ingress" {
  private_key_pem = tls_private_key.ingress.private_key_pem

  subject {
    common_name  = var.ingress_host
    organization = "i2btech"
  }

  validity_period_hours = 8760 # 1 year
  dns_names             = [var.ingress_host]

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# Crear Secret TLS en el namespace para el Ingress
resource "kubernetes_secret" "tls" {
  metadata {
    name      = "basicservice-tls"
    namespace = kubernetes_namespace.basicservice.metadata[0].name
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = tls_self_signed_cert.ingress.cert_pem
    "tls.key" = tls_private_key.ingress.private_key_pem
  }
}

module "basicservice" {
  source = "../../modules/basicservice"

  chart_path       = var.chart_path
  namespace        = kubernetes_namespace.basicservice.metadata[0].name
  htpasswd_content = var.htpasswd_content
  image_repository = var.image_repository
  image_tag        = var.image_tag
  replica_count    = var.replica_count
  logs_host_path   = var.logs_host_path
  ingress_host     = var.ingress_host
  tls_secret_name  = kubernetes_secret.tls.metadata[0].name

  depends_on = [kubernetes_namespace.basicservice, kubernetes_secret.tls]
}
