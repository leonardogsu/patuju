#!/bin/bash

#############################################
# Script de instalación desatendida de Docker
# y Docker Compose para Ubuntu 24.04
#############################################

set -e  # Detener el script si hay algún error

# Colores para mensajes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # Sin color

# Función para imprimir mensajes
print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[ADVERTENCIA]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar si el script se ejecuta como root o con sudo
if [[ $EUID -ne 0 ]]; then
   print_error "Este script debe ejecutarse como root o con sudo"
   exit 1
fi

# Obtener el nombre del usuario que invocó sudo
if [ -n "$SUDO_USER" ]; then
    REAL_USER=$SUDO_USER
else
    REAL_USER=$(whoami)
fi

print_message "Iniciando instalación de Docker y Docker Compose..."

# 1. Actualizar el sistema
print_message "Actualizando el sistema..."
apt update -y
apt upgrade -y

# 2. Instalar paquetes necesarios
print_message "Instalando dependencias..."
apt install -y ca-certificates curl gnupg lsb-release

# 3. Eliminar instalaciones antiguas de Docker (si existen)
print_message "Eliminando versiones antiguas de Docker (si existen)..."
apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# 4. Crear directorio para las claves
print_message "Configurando repositorio de Docker..."
install -m 0755 -d /etc/apt/keyrings

# 5. Añadir la clave GPG oficial de Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# 6. Configurar el repositorio
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# 7. Actualizar índice de paquetes
print_message "Actualizando índice de paquetes..."
apt update -y

# 8. Instalar Docker Engine y Docker Compose
print_message "Instalando Docker Engine, Docker Compose y plugins..."
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 9. Iniciar y habilitar el servicio Docker
print_message "Iniciando y habilitando el servicio Docker..."
systemctl start docker
systemctl enable docker

# 10. Añadir el usuario al grupo docker
if [ "$REAL_USER" != "root" ]; then
    print_message "Añadiendo el usuario '$REAL_USER' al grupo docker..."
    usermod -aG docker $REAL_USER
    print_warning "Necesitarás cerrar sesión e iniciar sesión nuevamente para usar Docker sin sudo"
fi

# 11. Verificar la instalación
print_message "Verificando la instalación..."
echo ""
docker --version
docker compose version
echo ""

# 12. Ejecutar contenedor de prueba
print_message "Ejecutando contenedor de prueba..."
docker run --rm hello-world

# Mensaje final
echo ""
print_message "¡Instalación completada con éxito!"
echo ""
print_message "Versiones instaladas:"
docker --version
docker compose version
echo ""

if [ "$REAL_USER" != "root" ]; then
    print_warning "Recuerda: Debes cerrar sesión y volver a iniciarla para usar Docker sin sudo"
    print_message "O ejecuta: newgrp docker (solo funciona en la sesión actual)"
fi

print_message "Para probar Docker Compose, puedes crear un archivo docker-compose.yml"
print_message "Script finalizado."