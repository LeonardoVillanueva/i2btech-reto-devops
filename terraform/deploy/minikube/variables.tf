# deploy/minikube/variables.tf
# Variables específicas del entorno Minikube

variable "kubeconfig_path" {
  description = "Ruta al kubeconfig de Minikube"
  type        = string
  default     = "~/.kube/config"
}

variable "chart_path" {
  description = "Ruta al Helm Chart (relativa a este directorio)"
  type        = string
  default     = "../../../helm/basicservice"
}

variable "namespace" {
  description = "Namespace de Kubernetes"
  type        = string
  default     = "basicservice"
}

variable "htpasswd_content" {
  description = "Contenido del archivo htpasswd generado externamente (ej: admin:$apr1$...)"
  type        = string
  sensitive   = true
}

variable "image_repository" {
  description = "Repositorio de la imagen Docker"
  type        = string
  default     = "basicservice"
}

variable "image_tag" {
  description = "Tag de la imagen Docker"
  type        = string
  default     = "latest"
}

variable "replica_count" {
  description = "Número de réplicas"
  type        = number
  default     = 1
}

variable "logs_host_path" {
  description = "Ruta hostPath para logs en el nodo Minikube"
  type        = string
  default     = "/mnt/logs/basicservice"
}

variable "ingress_host" {
  description = "Hostname del Ingress"
  type        = string
  default     = "basicservice.local"
}
