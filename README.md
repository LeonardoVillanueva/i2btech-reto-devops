# Reto DevOps i2btech -- basicservice

Solucion al reto tecnico para el puesto de DevOps Junior en i2btech.

El objetivo es tomar una aplicacion Node.js/Express que expone 4 endpoints REST y llevarla desde un entorno local con Docker hasta un cluster Kubernetes automatizado con Ansible, pasando por Helm y Terraform.

## Que hace la aplicacion

Es una API REST en Node.js (Express) que escucha en el puerto 3000:

- `GET /` -- devuelve `{"msg":"ApiRest prueba"}`
- `GET /public` -- devuelve `{"public_token":"12837asd98a7sasd97a9sd7"}`
- `GET /private` -- devuelve `{"private_token":"..."}` (debe estar protegido con auth basica)
- `GET /health_check` -- devuelve `Ok`

La app usa `pino` (libreria de logging de Node.js) para escribir un archivo `app.log` dentro de un folder `logs/` que se crea automaticamente junto al `index.js`. Cada request a `/public` y `/private` genera una linea de log en formato JSON. El reto pide que este folder se persista con un volumen, porque si el contenedor se reinicia los logs se perderian.

---

## Como se resolvio cada punto del reto

### 1. Dockerizar la aplicacion

Se creo un `Dockerfile` que empaqueta la app en una imagen `node:20-alpine` con usuario no-root.

Se creo un `docker-compose.yml` con dos servicios:
- **app**: la aplicacion Node.js (no expone puertos al host directamente)
- **nginx**: reverse proxy que termina TLS en puerto 443 y redirige HTTP a HTTPS

Nginx protege `/private` con `auth_basic` usando un archivo `.htpasswd` montado como volumen.

Los logs de la app se persisten con un volumen nombrado Docker (`app-logs`) montado en `/app/src/logs`.

Para probarlo localmente se incluye un script `setup.sh` que genera los certificados TLS y el `.htpasswd` automaticamente:

```bash
chmod +x setup.sh && ./setup.sh
docker compose up -d
curl -k https://localhost/health_check    # Ok
curl -k -u admin:admin123 https://localhost/private
```

### 2. Helm Chart

Se creo un chart en `helm/basicservice/` que despliega la app en Kubernetes con:

- **Deployment**: contenedor con la app, probes de salud, SecurityContext no-root, initContainer para permisos del volumen de logs.
- **Service**: ClusterIP en puerto 3000.
- **Ingress** (dos recursos):
  - Uno publico para `/`, `/public` y `/health_check` (sin auth).
  - Uno privado para `/private` con annotations de nginx para auth basica.
  - Ambos con TLS habilitado (certificado referenciado desde un Secret).
- **PersistentVolume + PVC**: tipo hostPath que mapea `/mnt/logs/basicservice` del nodo a `/app/src/logs` del contenedor. Asi los logs persisten aunque el pod se reinicie.
- **Secret**: contiene el htpasswd para la autenticacion basica del Ingress.

### 3. Terraform (despliegue declarativo)

El reto pide "deployar la aplicacion usando Terraform y el helm chart del punto 2". Terraform se encarga de:

- **Crear el namespace** `basicservice` con el provider `kubernetes`. Esto es mejor que usar `default` porque aisla los recursos de la app y permite limpiar todo con un `terraform destroy`.
- **Generar el certificado TLS** con el provider `tls` (en `terraform/deploy/minikube/main.tf`). Crea una clave RSA de 2048 bits y un certificado autofirmado valido por 1 anio para el dominio `basicservice.local`. Lo almacena como un Secret de tipo `kubernetes.io/tls` en el namespace. No se genera ningun archivo `.crt` en disco; Terraform lo crea en memoria y lo inyecta directamente en Kubernetes.
- **Desplegar el Helm chart** con el recurso `helm_release`. Le pasa las credenciales htpasswd, la configuracion de la imagen, el hostPath y el nombre del Secret TLS como variables.

La configuracion esta modularizada:
- `terraform/modules/basicservice/` -- modulo reutilizable que solo hace el `helm_release`
- `terraform/deploy/minikube/` -- entorno especifico que crea el namespace, el TLS y llama al modulo

El playbook pasa la variable `TF_VAR_htpasswd_content` como variable de entorno para que Terraform la inyecte al Helm chart sin escribirla en disco (sin `.tfvars`).

### 4. Automatizar con Ansible

El playbook (`ansible/playbook.yml`) hace todo desde cero en una maquina Ubuntu 24.04:

1. Instala Docker, kubectl, Minikube, Helm y Terraform
2. Inicia Minikube con driver Docker
3. Habilita el Ingress Controller (addon de Minikube)
4. Construye la imagen Docker dentro del contexto de Minikube (para que los pods la encuentren sin registry)
5. Crea el directorio hostPath en el nodo para los logs
6. Ejecuta `terraform init` y `terraform apply` (que crea namespace + TLS + helm release)
7. Configura `/etc/hosts` para que `basicservice.local` apunte a la IP de Minikube
8. Verifica que los 4 endpoints respondan correctamente via HTTPS

---

## Como ejecutar (el evaluador solo necesita hacer esto)

### Requisitos de la maquina

- Ubuntu 24.04 LTS
- Minimo 2 CPUs y 4 GB RAM (Minikube lo requiere)
- sudo sin password configurado (`visudo` -> `usuario ALL=(ALL) NOPASSWD: ALL`)
- Acceso a internet

### Comandos

```bash
sudo apt update && sudo apt install -y ansible git
git clone https://github.com/LeonardoVillanueva/i2btech-reto-devops.git
cd i2btech-reto-devops
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
```

Al terminar, los endpoints estan disponibles:

```
curl -k https://basicservice.local/health_check
curl -k https://basicservice.local/
curl -k https://basicservice.local/public
curl -k https://basicservice.local/private              # 401
curl -k -u admin:admin123 https://basicservice.local/private   # 200
```

---

## Decisiones tecnicas

- **Credenciales con defaults**: el reto dice "luego de ejecutar el playbook los 4 links deberian estar disponibles". Eso implica cero intervencion manual. Si usara Ansible Vault, el evaluador tendria que crear un archivo vault.yml, cifrarlo con `ansible-vault encrypt`, y pasar `--ask-vault-pass` al ejecutar. Eso son 3 pasos manuales que rompen el requisito. Por eso las credenciales (admin/admin123) van como variables con defaults directamente en el playbook.

- **Namespace dedicado via Terraform**: el reto dice "deployar la aplicacion usando Terraform y el helm chart". Terraform no solo ejecuta el Helm chart, sino que tambien crea el namespace `basicservice` como recurso gestionado. Esto tiene dos ventajas: (1) un `terraform destroy` limpia todo incluyendo el namespace, y (2) demuestra que Terraform gestiona el ciclo de vida completo de la infraestructura, no solo el deploy.

- **TLS autofirmado generado por Terraform**: el reto pide "exposicion segura en k8s". En Docker Compose se usa nginx con certificados generados por openssl. En Kubernetes, el equivalente es un Secret TLS que el Ingress Controller usa para terminar HTTPS. Terraform lo genera con el provider `tls` porque: (1) no requiere tener openssl instalado en la maquina, (2) el certificado queda gestionado como recurso de Terraform (se puede rotar con un `apply`), y (3) evita un paso extra en el playbook.

- **Imagen construida dentro de Minikube**: Minikube corre Docker dentro de una VM. Si construyes la imagen en el host, los pods no la encuentran porque buscan en el Docker interno de Minikube. Con `eval $(minikube docker-env)` apuntas tu cliente Docker al daemon de Minikube, asi la imagen queda disponible sin necesidad de un registry (Docker Hub, ECR, etc).

- **hostPath para logs**: el reto dice explicitamente "volumen persistente de tipo hostPath". Se eligio `/mnt/logs/basicservice` como ruta en el nodo porque: (1) `/mnt` es el directorio estandar para puntos de montaje en Linux, (2) el subdirectorio `basicservice` evita conflictos con otras apps, y (3) el playbook crea este directorio con permisos 775 y owner 1000 (el UID del usuario node en el contenedor) para que la app pueda escribir.

- **Playbook idempotente**: si el evaluador ejecuta el playbook dos veces, no falla. Helm no se reinstala si ya existe (tasks con `when: not helm_stat.stat.exists`), Minikube no se reinicia si ya esta corriendo, y Terraform no recrea recursos que ya existen.

---

## Validacion

Probado en VirtualBox con:
- Ubuntu 24.04 (Oracular Oriole) 64-bit
- 2 CPUs, 4782 MB RAM, 25 GB disco
- Red en modo Adaptador puente

Los 34 tasks del playbook ejecutan correctamente. Los 4 endpoints responden via HTTPS.

Para validar los logs persistentes:
```bash
curl -k https://basicservice.local/public
minikube ssh -- cat /mnt/logs/basicservice/app.log
```

---

## Estructura del proyecto

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
│       ├── service.yaml          # ClusterIP puerto 3000
│       ├── ingress.yaml          # Ingress con TLS y auth en /private
│       ├── pv.yaml               # PersistentVolume hostPath para logs
│       ├── pvc.yaml              # PersistentVolumeClaim
│       └── secret.yaml           # Secret con htpasswd
├── terraform/
│   ├── modules/basicservice/     # Modulo reutilizable (helm_release)
│   └── deploy/minikube/          # Entorno: namespace + TLS cert + modulo
├── ansible/
│   ├── inventory.ini             # localhost
│   └── playbook.yml              # Punto 3: orquestacion completa
└── i2btech-reto-devops/          # Codigo fuente original del reto
    └── src/
        ├── index.js
        └── package.json
```
