# modules/basicservice/main.tf
# Módulo reutilizable para desplegar basicservice via Helm

resource "helm_release" "basicservice" {
  name             = var.release_name
  chart            = var.chart_path
  namespace        = var.namespace
  create_namespace = true
  wait             = true
  timeout          = var.timeout_seconds

  set_sensitive {
    name  = "auth.htpasswdContent"
    value = var.htpasswd_content
  }

  set {
    name  = "image.repository"
    value = var.image_repository
  }

  set {
    name  = "image.tag"
    value = var.image_tag
  }

  set {
    name  = "replicaCount"
    value = var.replica_count
  }

  set {
    name  = "persistence.hostPath"
    value = var.logs_host_path
  }

  set {
    name  = "ingress.host"
    value = var.ingress_host
  }
}
