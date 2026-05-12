# deploy/minikube/outputs.tf

output "namespace" {
  description = "Namespace creado para la aplicacion"
  value       = kubernetes_namespace.basicservice.metadata[0].name
}

output "release_name" {
  description = "Nombre del Helm release"
  value       = module.basicservice.release_name
}

output "release_namespace" {
  description = "Namespace del despliegue"
  value       = module.basicservice.release_namespace
}

output "release_status" {
  description = "Estado del Helm release"
  value       = module.basicservice.release_status
}
