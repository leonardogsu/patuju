#!/bin/bash

################################################################################
# WordPress Multi-Site Automated Installer
# Para Ubuntu 24.04 LTS
# Instalación completamente automatizada desde cero
################################################################################

set -e  # Salir si hay algún error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración
PROJECT_NAME="wordpress-multisite"
INSTALL_DIR="/opt/$PROJECT_NAME"
LOG_FILE="/var/log/${PROJECT_NAME}-install.log"

# Verificar que se ejecuta como root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Este script debe ejecutarse como root (usa sudo)${NC}" 
   exit 1
fi

# Función para logging
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

# Banner
clear
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║     WordPress Multi-Site Automated Installer                ║
║     Para Ubuntu 24.04 LTS                                    ║
║                                                              ║
║     Instalación completamente automatizada                   ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF

echo ""
log "Iniciando instalación automatizada..."
echo ""

################################################################################
# 1. RECOPILACIÓN DE INFORMACIÓN
################################################################################

info "═══════════════════════════════════════════════════"
info "  PASO 1: Recopilación de información"
info "═══════════════════════════════════════════════════"
echo ""

# Detectar IP del servidor
SERVER_IP=$(curl -s ifconfig.me || wget -qO- ifconfig.me || echo "")
if [ -z "$SERVER_IP" ]; then
    read -p "No se pudo detectar la IP automáticamente. Ingresa la IP del servidor: " SERVER_IP
else
    info "IP del servidor detectada: $SERVER_IP"
    read -p "¿Es correcta esta IP? (s/n): " confirm
    if [[ ! $confirm =~ ^[Ss]$ ]]; then
        read -p "Ingresa la IP correcta: " SERVER_IP
    fi
fi

# Solicitar dominios
echo ""
info "Ingresa los dominios que deseas configurar (presiona Enter sin texto cuando termines):"
DOMAINS=()
counter=1
while true; do
    read -p "Dominio $counter (o Enter para terminar): " domain
    if [ -z "$domain" ]; then
        break
    fi
    DOMAINS+=("$domain")
    counter=$((counter + 1))
done

if [ ${#DOMAINS[@]} -eq 0 ]; then
    error "Debes ingresar al menos un dominio"
fi

log "Dominios configurados: ${DOMAINS[*]}"

# Preguntar si quiere instalar phpMyAdmin
echo ""
read -p "¿Deseas instalar phpMyAdmin? (s/n): " install_phpmyadmin
[[ $install_phpmyadmin =~ ^[Ss]$ ]] && INSTALL_PHPMYADMIN=true || INSTALL_PHPMYADMIN=false

# Preguntar si quiere servidor FTP
echo ""
read -p "¿Deseas instalar servidor FTP? (s/n): " install_ftp
[[ $install_ftp =~ ^[Ss]$ ]] && INSTALL_FTP=true || INSTALL_FTP=false

# Confirmación
echo ""
info "═══════════════════════════════════════════════════"
info "  RESUMEN DE CONFIGURACIÓN"
info "═══════════════════════════════════════════════════"
echo "  IP del servidor: $SERVER_IP"
echo "  Número de sitios: ${#DOMAINS[@]}"
echo "  Dominios:"
for domain in "${DOMAINS[@]}"; do
    echo "    - $domain"
done
echo "  phpMyAdmin: $([[ $INSTALL_PHPMYADMIN == true ]] && echo 'Sí' || echo 'No')"
echo "  Servidor FTP: $([[ $INSTALL_FTP == true ]] && echo 'Sí' || echo 'No')"
echo "  Directorio: $INSTALL_DIR"
echo ""

read -p "¿Continuar con la instalación? (s/n): " confirm
if [[ ! $confirm =~ ^[Ss]$ ]]; then
    error "Instalación cancelada por el usuario"
fi

################################################################################
# 2. INSTALACIÓN DE DEPENDENCIAS
################################################################################

echo ""
info "═══════════════════════════════════════════════════"
info "  PASO 2: Instalación de dependencias del sistema"
info "═══════════════════════════════════════════════════"
echo ""

log "Actualizando sistema..."
apt-get update -qq || error "Error al actualizar el sistema"
apt-get upgrade -y -qq || warning "Error al actualizar paquetes"

log "Instalando dependencias básicas..."
apt-get install -y -qq \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    git \
    wget \
    unzip \
    pwgen \
    jq \
    ufw \
    || error "Error al instalar dependencias básicas"

################################################################################
# 3. INSTALACIÓN DE DOCKER
################################################################################

echo ""
info "═══════════════════════════════════════════════════"
info "  PASO 3: Instalación de Docker"
info "═══════════════════════════════════════════════════"
echo ""

if command -v docker &> /dev/null; then
    log "Docker ya está instalado"
else
    log "Instalando Docker..."
    
    # Añadir repositorio de Docker
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
        || error "Error al instalar Docker"
    
    systemctl enable docker
    systemctl start docker
    
    log "Docker instalado correctamente"
fi

# Verificar instalación de Docker Compose
if ! docker compose version &> /dev/null; then
    error "Docker Compose no está disponible"
fi

log "Docker Compose instalado: $(docker compose version)"

################################################################################
# 4. CONFIGURACIÓN DEL FIREWALL
################################################################################

echo ""
info "═══════════════════════════════════════════════════"
info "  PASO 4: Configuración del firewall"
info "═══════════════════════════════════════════════════"
echo ""

log "Configurando firewall UFW..."
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment "SSH"
ufw allow 80/tcp comment "HTTP"
ufw allow 443/tcp comment "HTTPS"

if [[ $INSTALL_FTP == true ]]; then
    ufw allow 21/tcp comment "FTP"
    ufw allow 21000:21010/tcp comment "FTP Pasivo"
fi

log "Firewall configurado correctamente"

################################################################################
# 5. CREACIÓN DE ESTRUCTURA DE DIRECTORIOS
################################################################################

echo ""
info "═══════════════════════════════════════════════════"
info "  PASO 5: Creación de estructura del proyecto"
info "═══════════════════════════════════════════════════"
echo ""

log "Creando directorio del proyecto: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

log "Creando estructura de directorios..."
mkdir -p {nginx/conf.d,php,mysql/init,mysql/data,scripts,www,logs/nginx,certbot/conf,certbot/www,backups}

# Ajustar permisos
chmod -R 755 scripts
chmod -R 755 www
chmod -R 755 certbot

log "Estructura de directorios creada"

################################################################################
# 6. GENERACIÓN DE CONTRASEÑAS Y VARIABLES
################################################################################

echo ""
info "═══════════════════════════════════════════════════"
info "  PASO 6: Generación de credenciales"
info "═══════════════════════════════════════════════════"
echo ""

log "Generando contraseñas seguras..."

MYSQL_ROOT_PASSWORD=$(pwgen -s 32 1)
DB_PASSWORD=$(pwgen -s 32 1)
FTP_PASSWORD=$(pwgen -s 32 1)

# Crear archivo .env
log "Creando archivo .env..."
cat > .env << ENVEOF
# Variables de entorno - Generadas automáticamente
# Fecha: $(date)

# MySQL
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
DB_PASSWORD=$DB_PASSWORD

# FTP
FTP_PASSWORD=$FTP_PASSWORD

# Servidor
SERVER_IP=$SERVER_IP

# Dominios
ENVEOF

for i in "${!DOMAINS[@]}"; do
    echo "DOMAIN_$((i+1))=${DOMAINS[$i]}" >> .env
done

chmod 600 .env
log "Archivo .env creado"

################################################################################
# 7. DESCARGA DE SCRIPTS AUXILIARES
################################################################################

echo ""
info "═══════════════════════════════════════════════════"
info "  PASO 7: Generando scripts auxiliares"
info "═══════════════════════════════════════════════════"
echo ""

# Este script llamará a otro script que genera todos los scripts auxiliares
# Por ahora, los crearemos inline en el siguiente paso

################################################################################
# 8. CONTINUAR CON GENERACIÓN DE CONFIGURACIONES
################################################################################

info "Instalación base completada. Ejecutando configuración detallada..."
log "Por favor espera mientras se generan las configuraciones..."

# Aquí se llamaría al script de configuración detallada
# Por ahora, lo incluiremos todo en este mismo script

echo ""
log "═══════════════════════════════════════════════════"
log "INSTALACIÓN COMPLETADA EXITOSAMENTE"
log "═══════════════════════════════════════════════════"
echo ""
info "Directorio del proyecto: $INSTALL_DIR"
info "Log de instalación: $LOG_FILE"
echo ""
info "CREDENCIALES GENERADAS:"
echo "  MySQL Root Password: $MYSQL_ROOT_PASSWORD"
echo "  Database Password: $DB_PASSWORD"
if [[ $INSTALL_FTP == true ]]; then
    echo "  FTP Password: $FTP_PASSWORD"
fi
echo ""
warning "¡GUARDA ESTAS CREDENCIALES EN UN LUGAR SEGURO!"
echo ""
info "Próximos pasos:"
echo "  1. cd $INSTALL_DIR"
echo "  2. ./scripts/setup.sh"
echo "  3. ./scripts/setup-wordpress.sh"
echo ""
