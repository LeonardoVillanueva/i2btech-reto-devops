# Reto DevOps i2btech -- basicservice

Solucion al reto tecnico DevOps: despliegue de una aplicacion Node.js/Express con Docker, Helm, Terraform y Ansible.

---

## Requisitos de la maquina para ejecutar el playbook

El reto indica que el playbook se ejecuta en una maquina recien instalada con Ubuntu 24.04.
La maquina debe cumplir:

- **Sistema operativo**: Ubuntu 24.04 LTS (server o desktop)
- **CPUs**: minimo 2 (Minikube requiere al menos 2 cores)
- **RAM**: minimo 4 GB (recomendado 4782 MB o mas)
- **Disco**: minimo 20 GB libres
- **sudo sin password**: el usuario debe tener configurado NOPASSWD en sudoers
- **Conectividad**: acceso a internet para descargar paquetes y binarios

Para configurar sudo sin password (prerrequisito del reto):
```bash
sudo visudo
# Agregar al final:
# tu_usuario ALL=(ALL) NOPASSWD: ALL
```

---

## Ejecucion del playbook (punto 3 del reto)

```bash
# 1. Instalar Ansible (unico paso manual)
sudo apt update && sudo apt install -y ansible git

# 2. Clonar el repositorio
git clone https://github.com/LeonardoVillanueva/i2btech-reto-devops.git
cd i2btech-reto-devops

# 3. Ejecutar el playbook
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
```

Al finalizar, los 4 endpoints estan disponibles via HTTPS:

```
https://basicservice.local/              -> {"msg":"ApiRest prueba"}
https://basicservice.local/public        -> {"public_token":"12837asd98a7sasd97a9sd7"}
https://basicservice.local/private       -> 401 (sin credenciales) / 200 
https://basicservice.local/health_check  -> Ok
```

---

## Correspondencia con los puntos del reto

### 1. Dockerizar la aplicacion

| Requisito | Implementacion |
|---|---|
| 1a) Docker Compose + HTTPS con nginx | `docker-compose.yml` + `nginx/nginx.conf` + `Dockerfile` |
| 1b) /private protegido con auth_basic | `nginx/nginx.conf` -> location /private con auth_basic |
| 1c) Volumen para logs | `docker-compose.yml` -> volumen `app-logs` montado en `/app/src/logs` |

### 2. Helm Chart

| Requisito | Implementacion |
|---|---|
| 2a) Chart con exposicion segura | `helm/basicservice/` con Ingress TLS + auth basica en /private |

### 3. Automatizar con Ansible

| Requisito | Implementacion |
|---|---|
| 3a-i) Ubuntu 24.04 desde cero | Playbook instala Docker, kubectl, Minikube, Helm, Terraform |
| 3a-ii) sudo sin password | `become: true` en el playbook (prerrequisito de la maquina) |
| 3b) Minikube | FASE 7: `minikube start --driver=docker` |
| 3c) Terraform + Helm chart | FASE 11: `terraform apply` que despliega el Helm chart |
| 3d) /private con auth basica | Ingress annotation `nginx.ingress.kubernetes.io/auth-type: basic` |
| 3e) Logs con hostPath | `pv.yaml` + `pvc.yaml` con hostPath `/mnt/logs/basicservice` |
| 3f) 4 links via browser | FASE 12-13: configura /etc/hosts + verifica HTTPS |

---

## Decisiones de diseno

- **Credenciales con valores por defecto en el playbook**: el reto pide que todo funcione
  al ejecutar el playbook sin pasos manuales adicionales. Por eso las credenciales
  (admin/admin123) estan definidas como variables con defaults. Se pueden sobreescribir
  con `-e htpasswd_user=otro -e htpasswd_password=otro`.

- **Namespace dedicado `basicservice`**: Terraform crea el namespace con el provider
  `kubernetes` antes de desplegar el Helm chart. Esto demuestra gestion declarativa
  de la infraestructura en lugar de usar el namespace `default`.

- **Certificado TLS autofirmado via Terraform**: el provider `tls` genera el certificado
  programaticamente. Se almacena como Secret de tipo `kubernetes.io/tls` y el Ingress
  lo referencia para servir HTTPS. No se requiere generar certificados manualmente.

- **Idempotencia**: el playbook puede ejecutarse multiples veces sin errores. Los tasks
  que ya completaron su trabajo se marcan como `ok` o `skipping` (por ejemplo, Helm
  no se reinstala si ya existe).

- **Sin vault ni secretos en el repositorio**: no se usa Ansible Vault porque agregaria
  un paso manual (`--ask-vault-pass`). Los secretos se generan en runtime (htpasswd via
  `htpasswd -nb`, certificado TLS via Terraform).

---

## Validacion realizada

El playbook fue validado en:
- **VirtualBox** con Ubuntu 24.04 (Oracular Oriole) 64-bit
- **2 CPUs**, **4782 MB RAM**, **25 GB disco**
- **Red**: Adaptador puente (bridge)
- **Usuario**: con NOPASSWD configurado en sudoers

Resultado: los 34 tasks ejecutan correctamente, los 4 endpoints responden via HTTPS.

---

## Docker Compose (punto 1 del reto)

Para probar Docker Compose de forma independiente:

```bash
chmod +x setup.sh
./setup.sh
docker compose up -d
curl -k https://localhost/health_check
curl -k https://localhost/
curl -k https://localhost/public
curl -k -u admin:admin123 https://localhost/private
```

El script `setup.sh` genera los certificados TLS y el archivo `.htpasswd` necesarios
para que Nginx sirva HTTPS y proteja /private con auth_basic.

---

## Estructura del Proyecto

```
.
├── Dockerfile                    # Imagen Docker (node:20-alpine, usuario no-root)
├── docker-compose.yml            # Punto 1: app + nginx HTTPS
├── setup.sh                      # Genera secretos para Docker Compose
├── nginx/
│   └── nginx.conf                # Reverse proxy HTTPS + auth_basic en /private
├── secrets/
│   └── .gitkeep                  # Directorio para secretos (excluidos del repo)
├── helm/basicservice/            # Punto 2: Helm Chart
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── deployment.yaml       # Deployment con probes y SecurityContext
│       ├── service.yaml          # ClusterIP en puerto 3000
│       ├── ingress.yaml          # Ingress con TLS y auth en /private
│       ├── pv.yaml               # PersistentVolume hostPath
│       ├── pvc.yaml              # PersistentVolumeClaim
│       └── secret.yaml           # Secret con htpasswd
├── terraform/
│   ├── modules/basicservice/     # Modulo: helm_release
│   └── deploy/minikube/          # Entorno: namespace + TLS + modulo
├── ansible/
│   ├── inventory.ini             # localhost
│   └── playbook.yml              # Punto 3: orquestacion completa
└── i2btech-reto-devops/          # Codigo fuente original del reto
    └── src/
        ├── index.js
        └── package.json
```
