# modules/basicservice/variables.tf
# Variables de entrada del modulo

variable "release_name" {
  description = "Nombre del Helm release"
  type        = string
  default     = "basicservice"
}

variable "chart_path" {
  description = "Ruta al directorio del Helm Chart basicservice"
  type        = string
}

variable "namespace" {
  description = "Namespace de Kubernetes donde se desplegara el chart"
  type        = string
  default     = "basicservice"
}

variable "htpasswd_content" {
  description = "Contenido del archivo htpasswd (formato: usuario:hash) para auth_basic en /private"
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
  description = "Numero de replicas del Deployment"
  type        = number
  default     = 1
}

variable "logs_host_path" {
  description = "Ruta en el nodo host para persistir los logs (hostPath)"
  type        = string
  default     = "/mnt/logs/basicservice"
}

variable "ingress_host" {
  description = "Hostname del Ingress"
  type        = string
  default     = "basicservice.local"
}

variable "tls_secret_name" {
  description = "Nombre del Secret TLS para el Ingress"
  type        = string
  default     = "basicservice-tls"
}

variable "timeout_seconds" {
  description = "Timeout en segundos para esperar que el Helm release este listo"
  type        = number
  default     = 300
}
