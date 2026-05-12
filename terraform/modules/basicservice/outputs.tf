# modules/basicservice/outputs.tf
# Valores exportados por el módulo para uso en el root module o en otros módulos

output "release_name" {
  description = "Nombre del Helm release desplegado"
  value       = helm_release.basicservice.name
}

output "release_namespace" {
  description = "Namespace de Kubernetes donde se desplegó el chart"
  value       = helm_release.basicservice.namespace
}

output "release_status" {
  description = "Estado del Helm release"
  value       = helm_release.basicservice.status
}
