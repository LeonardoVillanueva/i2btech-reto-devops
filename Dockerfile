# Dockerfile para basicservice — Node.js/Express
# Imagen base mínima y segura: node:20-alpine (~50MB)
FROM node:20-alpine

# Directorio de trabajo
WORKDIR /app

# Copiar manifiestos de dependencias primero (aprovecha cache de capas)
COPY i2btech-reto-devops/src/package*.json ./src/

# Instalar solo dependencias de producción
RUN npm install --omit=dev --prefix ./src

# Copiar el código fuente completo
COPY i2btech-reto-devops/src/ ./src/

# Crear directorio de logs con permisos para el usuario node (UID 1000)
RUN mkdir -p /app/src/logs && chown -R node:node /app/src/logs

# Cambiar al usuario no-root antes de ejecutar la app
USER node

# Exponer el puerto de la aplicación
EXPOSE 3000

# Comando de inicio
CMD ["node", "src/index.js"]
