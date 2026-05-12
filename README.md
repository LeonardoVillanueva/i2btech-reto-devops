# Reto DevOps i2btech -- basicservice

Despliegue completo de la aplicacion Node.js/Express `basicservice` en cuatro fases progresivas: contenedorizacion con Docker y Nginx, empaquetado con Helm Chart, despliegue declarativo con Terraform y orquestacion end-to-end con Ansible sobre Minikube.

## Descripcion

La aplicacion expone cuatro endpoints en el puerto 3000:

| Endpoint | Descripcion | Autenticacion |
|---|---|---|
| `GET /` | Mensaje de bienvenida | No |
| `GET /public` | Token publico | No |
| `GET /private` | Token privado | HTTP Basic |
| `GET /health_check` | Estado de salud | No |

---

## Prerrequisitos

Para ejecutar cada fase de forma independiente se necesitan las herramientas correspondientes. Para la **Fase 4 (Ansible)**, solo se necesita Ansible instalado -- el playbook instala todo lo demas automaticamente.

| Herramienta | Fase | Instalacion |
|---|---|---|
| Docker + Compose | Fase 1 | [docs.docker.com](https://docs.docker.com/engine/install/) |
| Helm v3.15+ | Fase 2 | [helm.sh](https://helm.sh/docs/intro/install/) |
| Terraform v1.8+ | Fase 3 | [developer.hashicorp.com](https://developer.hashicorp.com/terraform/install) |
| Ansible v2.15+ | Fase 4 | `pip install ansible` |
| openssl | Fase 1 | Incluido en la mayoria de sistemas |

---

## Generacion de Secretos (solo para Fase 1 -- Docker Compose)

Los archivos sensibles nunca se incluyen en el repositorio. Para la Fase 1 (Docker Compose), se generan automaticamente con el script incluido:

```bash
chmod +x setup.sh
./setup.sh            # usa password por defecto: admin123
./setup.sh mi_pass    # o con password personalizado
```

El script genera:
- `secrets/nginx.crt` y `secrets/nginx.key` -- certificado TLS autofirmado
- `secrets/.htpasswd` -- credenciales HTTP Basic

> Para la Fase 4 (Ansible), el playbook genera todo automaticamente sin necesidad de secretos previos.

---

## Fase 1: Docker Compose (entorno local HTTPS)

### Generar secretos y levantar el entorno

```bash
# Generar certificados TLS y archivo htpasswd automaticamente
chmod +x setup.sh
./setup.sh

# O con una password personalizada
./setup.sh mi_password_segura

# Construir la imagen y levantar los servicios
docker compose up -d

# Ver logs en tiempo real
docker compose logs -f
```

### Verificar los cuatro endpoints

```bash
# Health check (debe responder "Ok")
curl -k https://localhost/health_check

# Ruta raiz (debe responder JSON con msg)
curl -k https://localhost/

# Ruta publica (debe responder JSON con public_token)
curl -k https://localhost/public

# Ruta privada con credenciales (debe responder JSON con private_token)
curl -k -u admin:admin123 https://localhost/private

# Ruta privada sin credenciales (debe responder 401)
curl -k -I https://localhost/private

# Verificar redireccion HTTP -> HTTPS (debe responder 301)
curl -I http://localhost/
```

### Detener el entorno

```bash
docker compose down
# Para eliminar tambien el volumen de logs:
docker compose down -v
```

---

## Fase 2: Helm Chart (Kubernetes)

### Prerrequisitos

```bash
# Iniciar Minikube
minikube start --driver=docker

# Habilitar addon Ingress
minikube addons enable ingress
```

### Validar el chart

```bash
# Lint del chart (debe pasar sin errores)
helm lint helm/basicservice

# Previsualizar los manifiestos generados
helm template basicservice helm/basicservice \
  --set auth.htpasswdContent="admin:$(openssl passwd -apr1 'password')"
```

### Instalar el chart

```bash
# Instalar con credenciales en namespace dedicado
helm install basicservice helm/basicservice \
  --namespace basicservice --create-namespace \
  --set auth.htpasswdContent="admin:$(openssl passwd -apr1 'tu_password')"

# Verificar el despliegue
kubectl get pods,svc,ingress,pv,pvc -n basicservice
```

### Verificar endpoints en Minikube

```bash
# Obtener IP de Minikube
MINIKUBE_IP=$(minikube ip)

# Agregar entrada en /etc/hosts
echo "$MINIKUBE_IP basicservice.local" | sudo tee -a /etc/hosts

# Verificar endpoints via HTTPS
curl -k https://basicservice.local/health_check
curl -k https://basicservice.local/
curl -k https://basicservice.local/public
curl -k -u admin:tu_password https://basicservice.local/private
curl -k -I https://basicservice.local/private  # -> 401
```

---

## Fase 3: Terraform

### Configurar variables

```bash
# Copiar el archivo de ejemplo
cp terraform/deploy/minikube/terraform.tfvars.example terraform/deploy/minikube/terraform.tfvars

# Editar con valores reales (este archivo esta en .gitignore)
nano terraform/deploy/minikube/terraform.tfvars
```

### Desplegar con Terraform

```bash
cd terraform/deploy/minikube

# Inicializar providers y modulos
terraform init

# Revisar el plan de despliegue
terraform plan

# Aplicar el despliegue
terraform apply

# O con la variable directamente (sin terraform.tfvars)
terraform apply \
  -var="htpasswd_content=$(htpasswd -nb admin tu_password)"
```

Terraform crea automaticamente:
- Namespace `basicservice`
- Certificado TLS autofirmado para el Ingress
- Secret TLS en el namespace
- Helm release con la aplicacion

### Destruir el despliegue

```bash
cd terraform/deploy/minikube
terraform destroy
```

---

## Fase 4: Ansible (orquestacion completa)

### Ejecutar el playbook

```bash
# Ejecutar el playbook completo (instala todo desde cero en Ubuntu 24.04)
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml

# Con credenciales personalizadas
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml \
  -e htpasswd_user=admin -e htpasswd_password=mi_password

# Con verbose para ver detalles
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml -v
```

El playbook realiza automaticamente:
1. Instala Docker, kubectl, Minikube, Helm y Terraform
2. Inicia Minikube con driver Docker
3. Habilita el addon Ingress
4. Construye la imagen Docker dentro de Minikube
5. Crea namespace `basicservice` via Terraform
6. Genera certificado TLS y despliega con Terraform + Helm
7. Configura `/etc/hosts` para `basicservice.local`
8. Verifica los cuatro endpoints via HTTPS

Luego de ejecutar el playbook, los 4 endpoints estan disponibles en:
- https://basicservice.local/
- https://basicservice.local/public
- https://basicservice.local/private (requiere credenciales)
- https://basicservice.local/health_check

---

## Estructura del Proyecto

```
.
├── Dockerfile                    # Imagen Docker de la app
├── .dockerignore                 # Exclusiones del build Docker
├── docker-compose.yml            # Orquestacion local con Nginx HTTPS
├── setup.sh                      # Script para generar secretos (Fase 1)
├── .gitignore                    # Exclusiones del repositorio
├── README.md                     # Este archivo
├── nginx/
│   └── nginx.conf                # Configuracion Nginx (TLS + auth_basic)
├── secrets/
│   └── .gitkeep                  # Directorio para secretos (no en repo)
├── helm/
│   └── basicservice/
│       ├── Chart.yaml            # Metadatos del chart
│       ├── values.yaml           # Valores parametrizables
│       └── templates/
│           ├── deployment.yaml   # Deployment con SecurityContext y probes
│           ├── service.yaml      # Service ClusterIP
│           ├── ingress.yaml      # Ingress con TLS y auth_basic en /private
│           ├── pv.yaml           # PersistentVolume hostPath
│           ├── pvc.yaml          # PersistentVolumeClaim
│           └── secret.yaml       # Secret con htpasswd
├── terraform/
│   ├── modules/
│   │   └── basicservice/         # Modulo reutilizable
│   │       ├── main.tf           # helm_release
│   │       ├── variables.tf      # Variables del modulo
│   │       └── outputs.tf        # Outputs del modulo
│   └── deploy/
│       └── minikube/             # Entorno de despliegue Minikube
│           ├── main.tf           # Namespace + TLS + Helm via modulo
│           ├── variables.tf      # Variables del entorno
│           ├── outputs.tf        # Outputs del entorno
│           └── terraform.tfvars.example
└── ansible/
    ├── inventory.ini             # Inventario (localhost)
    └── playbook.yml              # Playbook de orquestacion completa
```

---

## Seguridad

### Archivos excluidos del repositorio

Los siguientes archivos nunca deben estar en el repositorio:

- `secrets/nginx.crt`, `secrets/nginx.key` -- certificados TLS
- `secrets/.htpasswd` -- credenciales HTTP Basic
- `terraform/**/*.tfvars` -- variables con secretos
- `terraform/**/*.tfstate` -- estado de Terraform
- `helm/**/auth-values.yaml` -- values con credenciales

---

## Solucion de Problemas

### Docker Compose no levanta

```bash
# Verificar que los secretos existen
ls -la secrets/

# Ver logs de los servicios
docker compose logs nginx
docker compose logs app
```

### Nginx retorna 502 Bad Gateway

La app no esta disponible. Verificar:
```bash
docker compose ps
docker compose logs app
```

### Pod en estado Pending en Kubernetes

El PV hostPath no existe. Verificar:
```bash
kubectl describe pvc basicservice-logs-pvc -n basicservice
# Crear el directorio en el nodo Minikube si es necesario:
minikube ssh -- sudo mkdir -p /mnt/logs/basicservice
```

### Terraform falla con error de conexion

Minikube no esta corriendo:
```bash
minikube status
minikube start --driver=docker
```
