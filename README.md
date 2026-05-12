# Reto DevOps i2btech — basicservice

Despliegue completo de la aplicación Node.js/Express `basicservice` en cuatro fases progresivas: contenerización con Docker y Nginx, empaquetado con Helm Chart, despliegue declarativo con Terraform y orquestación end-to-end con Ansible sobre Minikube.

## Descripción

La aplicación expone cuatro endpoints en el puerto 3000:

| Endpoint | Descripción | Autenticación |
|---|---|---|
| `GET /` | Mensaje de bienvenida | No |
| `GET /public` | Token público | No |
| `GET /private` | Token privado | HTTP Basic |
| `GET /health_check` | Estado de salud | No |

---

## Prerrequisitos

| Herramienta | Versión mínima | Instalación |
|---|---|---|
| Docker | 24.x | [docs.docker.com](https://docs.docker.com/engine/install/) |
| Docker Compose | v2.x | Incluido con Docker Desktop |
| kubectl | v1.30+ | [kubernetes.io](https://kubernetes.io/docs/tasks/tools/) |
| Minikube | v1.33+ | [minikube.sigs.k8s.io](https://minikube.sigs.k8s.io/docs/start/) |
| Helm | v3.15+ | [helm.sh](https://helm.sh/docs/intro/install/) |
| Terraform | v1.8+ | [developer.hashicorp.com](https://developer.hashicorp.com/terraform/install) |
| Ansible | v2.15+ | `pip install ansible` |
| openssl | cualquiera | Incluido en la mayoría de sistemas |
| htpasswd | cualquiera | `apt install apache2-utils` |

---

## Generación de Secretos (requerido antes de cualquier fase)

Los archivos sensibles **nunca** se incluyen en el repositorio. Deben generarse localmente antes de ejecutar cualquier fase.

### 1. Certificado TLS autofirmado

```bash
# Generar clave privada y certificado autofirmado (válido 365 días)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout secrets/nginx.key \
  -out secrets/nginx.crt \
  -subj "/C=CL/ST=Santiago/L=Santiago/O=i2btech/CN=localhost"
```

### 2. Archivo htpasswd para autenticación HTTP Basic

```bash
# Opción A: usando htpasswd (requiere apache2-utils)
htpasswd -c secrets/.htpasswd admin
# Ingresa la contraseña cuando se solicite

# Opción B: usando openssl (sin dependencias adicionales)
echo "admin:$(openssl passwd -apr1 'tu_contraseña_segura')" > secrets/.htpasswd
```

---

## Fase 1: Docker Compose (entorno local HTTPS)

### Levantar el entorno

```bash
# Construir la imagen y levantar los servicios
docker compose up -d

# Ver logs en tiempo real
docker compose logs -f
```

### Verificar los cuatro endpoints

```bash
# Health check (debe responder "Ok")
curl -k https://localhost/health_check

# Ruta raíz (debe responder JSON con msg)
curl -k https://localhost/

# Ruta pública (debe responder JSON con public_token)
curl -k https://localhost/public

# Ruta privada con credenciales (debe responder JSON con private_token)
curl -k -u admin:tu_contraseña https://localhost/private

# Ruta privada sin credenciales (debe responder 401)
curl -k -I https://localhost/private

# Verificar redirección HTTP → HTTPS (debe responder 301)
curl -I http://localhost/
```

### Detener el entorno

```bash
docker compose down
# Para eliminar también el volumen de logs:
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
# Instalar con credenciales
helm install basicservice helm/basicservice \
  --set auth.htpasswdContent="admin:$(openssl passwd -apr1 'tu_contraseña')"

# Verificar el despliegue
kubectl get pods,svc,ingress,pv,pvc
```

### Verificar endpoints en Minikube

```bash
# Obtener IP de Minikube
MINIKUBE_IP=$(minikube ip)

# Agregar entrada en /etc/hosts (opcional)
echo "$MINIKUBE_IP basicservice.local" | sudo tee -a /etc/hosts

# Verificar endpoints
curl -k http://basicservice.local/health_check
curl -k http://basicservice.local/public
curl -k -u admin:tu_contraseña http://basicservice.local/private
curl -k -I http://basicservice.local/private  # → 401
```

---

## Fase 3: Terraform

### Configurar variables

```bash
# Copiar el archivo de ejemplo
cp terraform/deploy/minikube/terraform.tfvars.example terraform/deploy/minikube/terraform.tfvars

# Editar con valores reales (este archivo está en .gitignore)
nano terraform/deploy/minikube/terraform.tfvars
```

### Desplegar con Terraform

```bash
cd terraform/deploy/minikube

# Inicializar providers y módulos
terraform init

# Revisar el plan de despliegue
terraform plan

# Aplicar el despliegue
terraform apply

# O con variables directamente (sin terraform.tfvars)
terraform apply \
  -var="htpasswd_user=admin" \
  -var="htpasswd_password=tu_contraseña"
```

### Destruir el despliegue

```bash
cd terraform/deploy/minikube
terraform destroy
```

---

## Fase 4: Ansible (orquestación completa)

### Configurar el vault de credenciales

```bash
# Copiar el archivo de ejemplo
cp ansible/vars/vault.yml.example ansible/vars/vault.yml

# Editar con credenciales reales
nano ansible/vars/vault.yml

# Cifrar el archivo con Ansible Vault
ansible-vault encrypt ansible/vars/vault.yml
```

### Ejecutar el playbook

```bash
# Ejecutar el playbook completo (instala todo desde cero)
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --ask-vault-pass

# Con verbose para ver detalles
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --ask-vault-pass -v
```

El playbook realiza automáticamente:
1. Instala Docker, kubectl, Minikube, Helm y Terraform
2. Inicia Minikube con driver Docker
3. Habilita el addon Ingress
4. Ejecuta `terraform init` y `terraform apply`
5. Verifica los cuatro endpoints

---

## Estructura del Proyecto

```
.
├── Dockerfile                    # Imagen Docker de la app
├── .dockerignore                 # Exclusiones del build Docker
├── docker-compose.yml            # Orquestación local con Nginx
├── .gitignore                    # Exclusiones del repositorio
├── README.md                     # Este archivo
├── nginx/
│   └── nginx.conf                # Configuración Nginx (TLS + auth_basic)
├── secrets/
│   └── .gitkeep                  # Directorio para secretos (no en repo)
├── helm/
│   └── basicservice/
│       ├── Chart.yaml            # Metadatos del chart
│       ├── values.yaml           # Valores parametrizables
│       └── templates/
│           ├── deployment.yaml   # Deployment con SecurityContext y probes
│           ├── service.yaml      # Service ClusterIP
│           ├── ingress.yaml      # Ingress con auth_basic en /private
│           ├── pv.yaml           # PersistentVolume hostPath
│           ├── pvc.yaml          # PersistentVolumeClaim
│           └── secret.yaml       # Secret con htpasswd
├── terraform/
│   ├── modules/
│   │   └── basicservice/         # Módulo reutilizable
│   │       ├── main.tf           # helm_release + locals htpasswd
│   │       ├── variables.tf      # Variables del módulo
│   │       └── outputs.tf        # Outputs del módulo
│   └── deploy/
│       └── minikube/             # Entorno de despliegue Minikube
│           ├── main.tf           # Provider + invocación del módulo
│           ├── variables.tf      # Variables del entorno
│           ├── outputs.tf        # Outputs del entorno
│           └── terraform.tfvars.example
└── ansible/
    ├── inventory.ini             # Inventario (localhost)
    ├── playbook.yml              # Playbook de orquestación completa
    └── vars/
        └── vault.yml.example     # Estructura del vault (sin secretos)
```

---

## Seguridad

### Archivos excluidos del repositorio

Los siguientes archivos **nunca** deben estar en el repositorio:

- `secrets/nginx.crt`, `secrets/nginx.key` — certificados TLS
- `secrets/.htpasswd` — credenciales HTTP Basic
- `terraform/terraform.tfvars` — variables con secretos
- `terraform/terraform.tfstate` — estado de Terraform
- `ansible/vars/vault.yml` — vault cifrado con credenciales

### Procedimiento de emergencia: purgar historial git

Si accidentalmente se commitea un archivo sensible:

```bash
# Instalar git-filter-repo
pip install git-filter-repo

# Eliminar el archivo del historial completo
git filter-repo --path secrets/nginx.key --invert-paths

# Forzar push (DESTRUCTIVO — coordinar con el equipo)
git push origin --force --all

# Revocar y regenerar las credenciales comprometidas inmediatamente
```

> **Importante**: Después de purgar el historial, todos los colaboradores deben clonar el repositorio nuevamente. Las credenciales comprometidas deben revocarse inmediatamente, independientemente de si se purga el historial.

---

## Solución de Problemas

### Docker Compose no levanta

```bash
# Verificar que los secretos existen
ls -la secrets/

# Ver logs de los servicios
docker compose logs nginx
docker compose logs app
```

### Nginx retorna 502 Bad Gateway

La app no está disponible. Verificar:
```bash
docker compose ps
docker compose logs app
```

### Pod en estado Pending en Kubernetes

El PV hostPath no existe. Verificar:
```bash
kubectl describe pvc basicservice-logs-pvc
# Crear el directorio en el nodo Minikube si es necesario:
minikube ssh -- sudo mkdir -p /mnt/logs/basicservice
```

### Terraform falla con error de conexión

Minikube no está corriendo:
```bash
minikube status
minikube start --driver=docker
```
