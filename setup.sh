#!/bin/bash
# setup.sh -- Genera los secretos necesarios para Docker Compose (Fase 1)
# Uso: ./setup.sh [password]
#
# Si no se pasa password, usa "admin123" por defecto

set -e

PASSWORD="${1:-admin123}"
SECRETS_DIR="./secrets"

echo "Generando secretos en ${SECRETS_DIR}/ ..."

# Crear directorio si no existe
mkdir -p "$SECRETS_DIR"

# Generar certificado TLS autofirmado (si no existe)
if [ ! -f "$SECRETS_DIR/nginx.crt" ] || [ ! -f "$SECRETS_DIR/nginx.key" ]; then
  echo "  Generando certificado TLS autofirmado..."
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$SECRETS_DIR/nginx.key" \
    -out "$SECRETS_DIR/nginx.crt" \
    -subj "/C=CL/ST=Santiago/L=Santiago/O=i2btech/CN=localhost" \
    2>/dev/null
  echo "  Certificado TLS generado"
else
  echo "  Certificado TLS ya existe, omitiendo"
fi

# Generar archivo htpasswd (si no existe)
if [ ! -f "$SECRETS_DIR/.htpasswd" ]; then
  echo "  Generando archivo .htpasswd (usuario: admin)..."
  echo "admin:$(openssl passwd -apr1 "$PASSWORD")" > "$SECRETS_DIR/.htpasswd"
  echo "  Archivo .htpasswd generado"
else
  echo "  Archivo .htpasswd ya existe, omitiendo"
fi

echo ""
echo "Secretos listos. Ahora puedes ejecutar:"
echo "  docker compose up -d"
echo ""
echo "Credenciales: admin / ${PASSWORD}"
