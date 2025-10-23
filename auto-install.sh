#!/bin/bash

################################################################################
# WordPress Multi-Site - Instalador Automático Completo
# Ejecuta todo el proceso de instalación desde cero
# Para Ubuntu 24.04 LTS
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuración
PROJECT_NAME="wordpress-multisite"
INSTALL_DIR="/opt/$PROJECT_NAME"
LOG_FILE="/var/log/${PROJECT_NAME}-install.log"

# Crear directorio de logs si no existe
mkdir -p "$(dirname "$LOG_FILE")"

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

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

banner() {
    echo -e "${CYAN}$1${NC}" | tee -a "$LOG_FILE"
}

# Verificar root
if [[ $EUID -ne 0 ]]; then
   error "Este script debe ejecutarse como root (usa sudo)"
fi

# Banner principal
clear
cat << "EOF"
╔═══════════════════════════════════════════════════════════════════════╗
║                                                                       ║
║            WordPress Multi-Site Instalador Automático                ║
║                     Para Ubuntu 24.04 LTS                             ║
║                                                                       ║
║                  Instalación Completamente Automatizada               ║
║                                                                       ║
╚═══════════════════════════════════════════════════════════════════════╝
EOF

echo ""
log "Iniciando instalación automática completa..."
log "Los logs se guardan en: $LOG_FILE"
echo ""
sleep 2

################################################################################
# 1. VERIFICACIÓN DE REQUISITOS MÍNIMOS
################################################################################

banner "═══════════════════════════════════════════════════════════════════════"
banner "  PASO 1: Verificación de requisitos del sistema"
banner "═══════════════════════════════════════════════════════════════════════"
echo ""

# Verificar Ubuntu 24.04
info "Verificando versión de Ubuntu..."
if ! grep -q "24.04" /etc/os-release; then
    warning "Este script está diseñado para Ubuntu 24.04 LTS"
    read -p "¿Continuar de todos modos? (s/n): " continue_anyway
    if [[ ! $continue_anyway =~ ^[Ss]$ ]]; then
        error "Instalación cancelada"
    fi
else
    success "✓ Ubuntu 24.04 LTS detectado"
fi

# Verificar RAM
info "Verificando memoria RAM..."
ram_mb=$(free -m | awk 'NR==2{print $2}')
if [ $ram_mb -lt 4000 ]; then
    warning "Se recomienda al menos 8GB de RAM. Sistema tiene: ${ram_mb}MB"
else
    success "✓ RAM suficiente: ${ram_mb}MB"
fi

# Verificar espacio en disco
info "Verificando espacio en disco..."
disk_gb=$(df / | awk 'NR==2{print int($4/1024/1024)}')
if [ $disk_gb -lt 20 ]; then
    warning "Se recomienda al menos 20GB libres. Disponible: ${disk_gb}GB"
else
    success "✓ Espacio en disco suficiente: ${disk_gb}GB"
fi

echo ""
sleep 2

################################################################################
# 2. RECOPILACIÓN DE INFORMACIÓN
################################################################################

banner "═══════════════════════════════════════════════════════════════════════"
banner "  PASO 2: Recopilación de información"
banner "═══════════════════════════════════════════════════════════════════════"
echo ""

# Detectar IP
info "Detectando IP pública del servidor..."
SERVER_IP=$(curl -s --max-time 10 ifconfig.me || curl -s --max-time 10 icanhazip.com || echo "")
if [ -z "$SERVER_IP" ]; then
    read -p "No se pudo detectar la IP. Ingresa la IP del servidor: " SERVER_IP
else
    echo "  IP detectada: $SERVER_IP"
    read -p "  ¿Es correcta? (s/n): " confirm
    if [[ ! $confirm =~ ^[Ss]$ ]]; then
        read -p "  Ingresa la IP correcta: " SERVER_IP
    fi
fi

# Solicitar dominios
echo ""
info "Ingresa los dominios (presiona Enter sin texto cuando termines):"
DOMAINS=()
counter=1
while true; do
    read -p "  Dominio $counter (o Enter para terminar): " domain
    if [ -z "$domain" ]; then
        break
    fi
    # Validar formato de dominio
    if [[ $domain =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
        DOMAINS+=("$domain")
        counter=$((counter + 1))
    else
        warning "    Formato de dominio inválido, intenta de nuevo"
    fi
done

if [ ${#DOMAINS[@]} -eq 0 ]; then
    error "Debes ingresar al menos un dominio"
fi

# Opciones adicionales
echo ""
read -p "¿Instalar phpMyAdmin? (s/n): " install_phpmyadmin
[[ $install_phpmyadmin =~ ^[Ss]$ ]] && INSTALL_PHPMYADMIN=true || INSTALL_PHPMYADMIN=false

read -p "¿Instalar servidor FTP? (s/n): " install_ftp
[[ $install_ftp =~ ^[Ss]$ ]] && INSTALL_FTP=true || INSTALL_FTP=false

read -p "¿Configurar backup automático diario? (s/n): " setup_cron
[[ $setup_cron =~ ^[Ss]$ ]] && SETUP_CRON=true || SETUP_CRON=false

# Resumen
echo ""
banner "═══════════════════════════════════════════════════════════════════════"
banner "  RESUMEN DE CONFIGURACIÓN"
banner "═══════════════════════════════════════════════════════════════════════"
echo "  IP del servidor: $SERVER_IP"
echo "  Número de sitios: ${#DOMAINS[@]}"
echo "  Dominios:"
for domain in "${DOMAINS[@]}"; do
    echo "    - $domain"
done
echo "  phpMyAdmin: $([[ $INSTALL_PHPMYADMIN == true ]] && echo 'Sí' || echo 'No')"
echo "  Servidor FTP: $([[ $INSTALL_FTP == true ]] && echo 'Sí' || echo 'No')"
echo "  Backup automático: $([[ $SETUP_CRON == true ]] && echo 'Sí' || echo 'No')"
echo "  Directorio: $INSTALL_DIR"
echo ""

read -p "¿Continuar con la instalación? (s/n): " confirm
if [[ ! $confirm =~ ^[Ss]$ ]]; then
    error "Instalación cancelada"
fi

echo ""
sleep 2

################################################################################
# 3. ACTUALIZACIÓN DEL SISTEMA
################################################################################

banner "═══════════════════════════════════════════════════════════════════════"
banner "  PASO 3: Actualización del sistema"
banner "═══════════════════════════════════════════════════════════════════════"
echo ""

log "Actualizando repositorios..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq >> "$LOG_FILE" 2>&1 || error "Error al actualizar repositorios"
success "✓ Repositorios actualizados"

log "Instalando actualizaciones del sistema..."
apt-get upgrade -y -qq >> "$LOG_FILE" 2>&1 || warning "Algunas actualizaciones fallaron"
success "✓ Sistema actualizado"

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
    cron \
    >> "$LOG_FILE" 2>&1 || error "Error al instalar dependencias"
success "✓ Dependencias instaladas"

echo ""
sleep 2

################################################################################
# 4. INSTALACIÓN DE DOCKER
################################################################################

banner "═══════════════════════════════════════════════════════════════════════"
banner "  PASO 4: Instalación de Docker y Docker Compose"
banner "═══════════════════════════════════════════════════════════════════════"
echo ""

if command -v docker &> /dev/null; then
    success "✓ Docker ya está instalado: $(docker --version)"
else
    log "Instalando Docker..."

    # Añadir la GPG key oficial de Docker
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    # Añadir el repositorio
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update -qq >> "$LOG_FILE" 2>&1
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >> "$LOG_FILE" 2>&1 || error "Error al instalar Docker"

    success "✓ Docker instalado: $(docker --version)"
fi

# Verificar Docker Compose
if docker compose version &> /dev/null; then
    success "✓ Docker Compose: $(docker compose version)"
else
    error "Docker Compose no está disponible"
fi

# Iniciar Docker
systemctl enable docker >> "$LOG_FILE" 2>&1
systemctl start docker >> "$LOG_FILE" 2>&1
success "✓ Servicio Docker iniciado"

echo ""
sleep 2

################################################################################
# 5. CONFIGURACIÓN DEL FIREWALL
################################################################################

banner "═══════════════════════════════════════════════════════════════════════"
banner "  PASO 5: Configuración del firewall"
banner "═══════════════════════════════════════════════════════════════════════"
echo ""

log "Configurando UFW..."
ufw --force enable >> "$LOG_FILE" 2>&1
ufw default deny incoming >> "$LOG_FILE" 2>&1
ufw default allow outgoing >> "$LOG_FILE" 2>&1
ufw allow 22/tcp comment "SSH" >> "$LOG_FILE" 2>&1
ufw allow 80/tcp comment "HTTP" >> "$LOG_FILE" 2>&1
ufw allow 443/tcp comment "HTTPS" >> "$LOG_FILE" 2>&1

if [[ $INSTALL_FTP == true ]]; then
    ufw allow 21/tcp comment "FTP" >> "$LOG_FILE" 2>&1
    ufw allow 21000:21010/tcp comment "FTP Pasivo" >> "$LOG_FILE" 2>&1
fi

success "✓ Firewall configurado"

echo ""
sleep 2

################################################################################
# 6. CREACIÓN DE ESTRUCTURA DE PROYECTO
################################################################################

banner "═══════════════════════════════════════════════════════════════════════"
banner "  PASO 6: Creación de estructura del proyecto"
banner "═══════════════════════════════════════════════════════════════════════"
echo ""

log "Creando directorio: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

log "Creando estructura de directorios..."
mkdir -p {nginx/conf.d,php,mysql/init,mysql/data,scripts,www,logs/nginx,certbot/conf,certbot/www,backups}
chmod -R 755 scripts www certbot
success "✓ Estructura creada"

echo ""
sleep 2

################################################################################
# 7. LIMPIEZA DE VOLÚMENES Y CONTENEDORES ANTIGUOS DE WORDPRESS
################################################################################

banner "═══════════════════════════════════════════════════════════════════════"
banner "  PASO 7: Detección y limpieza de instalaciones anteriores"
banner "═══════════════════════════════════════════════════════════════════════"
echo ""

FOUND_OLD_DATA=false

# Detectar contenedores relacionados con WordPress
log "Buscando contenedores antiguos de WordPress/MySQL/Nginx..."
OLD_CONTAINERS=$(docker ps -a --filter "name=nginx" --filter "name=mysql" --filter "name=php" --filter "name=wordpress" --filter "name=phpmyadmin" --filter "name=certbot" --filter "name=ftp" --format "{{.Names}}" 2>/dev/null || true)

if [ -n "$OLD_CONTAINERS" ]; then
    FOUND_OLD_DATA=true
    warning "Se encontraron contenedores antiguos:"
    echo "$OLD_CONTAINERS" | while read container; do
        echo "  - $container"
    done
    echo ""
fi

# Detectar volúmenes de Docker
log "Buscando volúmenes de Docker antiguos..."
OLD_VOLUMES=$(docker volume ls --filter "name=mysql" --filter "name=wordpress" --filter "name=wp" --format "{{.Name}}" 2>/dev/null || true)

if [ -n "$OLD_VOLUMES" ]; then
    FOUND_OLD_DATA=true
    warning "Se encontraron volúmenes de Docker antiguos:"
    echo "$OLD_VOLUMES" | while read volume; do
        echo "  - $volume"
    done
    echo ""
fi

# Detectar directorios de datos antiguos
log "Buscando directorios de datos antiguos..."
OLD_DIRS=()

if [ -d "$INSTALL_DIR/www" ] && [ "$(ls -A $INSTALL_DIR/www 2>/dev/null)" ]; then
    OLD_DIRS+=("$INSTALL_DIR/www")
fi

if [ -d "$INSTALL_DIR/mysql/data" ] && [ "$(ls -A $INSTALL_DIR/mysql/data 2>/dev/null)" ]; then
    OLD_DIRS+=("$INSTALL_DIR/mysql/data")
fi

if [ ${#OLD_DIRS[@]} -gt 0 ]; then
    FOUND_OLD_DATA=true
    warning "Se encontraron directorios con datos antiguos:"
    for dir in "${OLD_DIRS[@]}"; do
        echo "  - $dir"
    done
    echo ""
fi

# Detectar redes de Docker
log "Buscando redes de Docker antiguas..."
OLD_NETWORKS=$(docker network ls --filter "name=wordpress" --filter "name=wp" --format "{{.Name}}" 2>/dev/null | grep -v "bridge\|host\|none" || true)

if [ -n "$OLD_NETWORKS" ]; then
    FOUND_OLD_DATA=true
    warning "Se encontraron redes de Docker antiguas:"
    echo "$OLD_NETWORKS" | while read network; do
        echo "  - $network"
    done
    echo ""
fi

# Si se encontró algo, preguntar al usuario
if [ "$FOUND_OLD_DATA" = true ]; then
    warning "╔═══════════════════════════════════════════════════════════════╗"
    warning "║  ATENCIÓN: Se detectaron instalaciones previas de WordPress  ║"
    warning "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    warning "Para garantizar una instalación limpia, se recomienda eliminar todos"
    warning "los contenedores, volúmenes y datos antiguos."
    echo ""
    warning "⚠️  ESTA ACCIÓN ES IRREVERSIBLE ⚠️"
    warning "Se perderán todos los datos, bases de datos y archivos antiguos."
    echo ""
    read -p "¿Deseas eliminar TODAS las instalaciones antiguas y empezar de cero? (s/n): " confirm_cleanup

    if [[ $confirm_cleanup =~ ^[Ss]$ ]]; then
        log "Iniciando limpieza completa..."
        echo ""

        # Detener y eliminar contenedores
        if [ -n "$OLD_CONTAINERS" ]; then
            log "Deteniendo contenedores antiguos..."
            echo "$OLD_CONTAINERS" | while read container; do
                docker stop "$container" >> "$LOG_FILE" 2>&1 || true
                info "  ✓ Detenido: $container"
            done

            log "Eliminando contenedores antiguos..."
            echo "$OLD_CONTAINERS" | while read container; do
                docker rm -f "$container" >> "$LOG_FILE" 2>&1 || true
                info "  ✓ Eliminado: $container"
            done
        fi

        # Eliminar volúmenes de Docker
        if [ -n "$OLD_VOLUMES" ]; then
            log "Eliminando volúmenes de Docker antiguos..."
            echo "$OLD_VOLUMES" | while read volume; do
                docker volume rm "$volume" >> "$LOG_FILE" 2>&1 || true
                info "  ✓ Eliminado volumen: $volume"
            done
        fi

        # Eliminar directorios de datos
        if [ ${#OLD_DIRS[@]} -gt 0 ]; then
            log "Eliminando directorios de datos antiguos..."
            for dir in "${OLD_DIRS[@]}"; do
                rm -rf "$dir"/* >> "$LOG_FILE" 2>&1 || true
                info "  ✓ Limpiado: $dir"
            done
        fi

        # Eliminar redes de Docker
        if [ -n "$OLD_NETWORKS" ]; then
            log "Eliminando redes de Docker antiguas..."
            echo "$OLD_NETWORKS" | while read network; do
                docker network rm "$network" >> "$LOG_FILE" 2>&1 || true
                info "  ✓ Eliminada red: $network"
            done
        fi

        # Limpieza adicional de Docker
        log "Ejecutando limpieza general de Docker..."
        docker system prune -f >> "$LOG_FILE" 2>&1 || true

        success "✅ Limpieza completa finalizada"
        success "El sistema está listo para una instalación completamente nueva"
    else
        warning "⚠️  ATENCIÓN: Se detectaron instalaciones previas pero no se eliminaron"
        warning "Esto puede causar conflictos durante la instalación."
        echo ""
        read -p "¿Deseas continuar de todos modos? (s/n): " continue_anyway
        if [[ ! $continue_anyway =~ ^[Ss]$ ]]; then
            error "Instalación cancelada por el usuario"
        fi
    fi
else
    success "✓ No se detectaron instalaciones previas"
    success "Sistema listo para instalación limpia"
fi

echo ""
sleep 2

################################################################################
# 8. VERIFICACIÓN DE VOLUMEN DE DATOS MYSQL EXISTENTE
################################################################################

banner "═══════════════════════════════════════════════════════════════════════"
banner "  PASO 8: Verificación de volumen de datos MySQL"
banner "═══════════════════════════════════════════════════════════════════════"
echo ""

MYSQL_DATA_DIR="$INSTALL_DIR/mysql/data"

if [ -d "$MYSQL_DATA_DIR" ] && [ "$(ls -A $MYSQL_DATA_DIR 2>/dev/null)" ]; then
    warning "Se ha detectado un volumen de datos MySQL existente en:"
    echo "  $MYSQL_DATA_DIR"
    echo ""
    echo "Esto significa que:"
    echo "  - MySQL ya tiene una contraseña root previa."
    echo "  - Si continúas, la instalación puede fallar al no coincidir las credenciales."
    echo ""
    read -p "¿Deseas borrar el volumen de datos MySQL y reiniciar limpio? (s/n): " confirm_delete

    if [[ $confirm_delete =~ ^[Ss]$ ]]; then
        log "Deteniendo contenedores existentes (si los hay)..."
        docker compose -f "$INSTALL_DIR/docker-compose.yml" down 2>/dev/null || true

        log "Eliminando datos existentes de MySQL..."
        rm -rf "$MYSQL_DATA_DIR"/*

        success "✓ Volumen de datos MySQL eliminado correctamente"
    else
        warning "⚠️ ATENCIÓN: Se usará el volumen existente."
        warning "Si la contraseña root no coincide, la instalación fallará."
        echo ""
        read -p "¿Deseas continuar de todos modos? (s/n): " continue_anyway
        if [[ ! $continue_anyway =~ ^[Ss]$ ]]; then
            error "Instalación cancelada por el usuario."
        fi
    fi
else
    success "✓ No se detectó volumen de MySQL previo. Continuando instalación..."
fi

echo ""
sleep 2


################################################################################
# 9. GENERACIÓN DE CREDENCIALES
################################################################################

banner "═══════════════════════════════════════════════════════════════════════"
banner "  PASO 9: Generación de credenciales seguras"
banner "═══════════════════════════════════════════════════════════════════════"
echo ""

log "Generando contraseñas aleatorias..."
MYSQL_ROOT_PASSWORD=$(pwgen -s 32 1)
DB_PASSWORD=$(pwgen -s 32 1)
FTP_PASSWORD=$(pwgen -s 32 1)
success "✓ Credenciales generadas"

# Guardar credenciales
CREDENTIALS_FILE="$INSTALL_DIR/.credentials"
cat > "$CREDENTIALS_FILE" << CREDEOF
# CREDENCIALES DEL SISTEMA
# Generadas: $(date)
# GUARDAR EN LUGAR SEGURO

MySQL Root Password: $MYSQL_ROOT_PASSWORD
Database Password: $DB_PASSWORD
FTP Password: $FTP_PASSWORD
CREDEOF
chmod 600 "$CREDENTIALS_FILE"

# Crear .env
log "Creando archivo .env..."
cat > .env << ENVEOF
# Variables de entorno
# Generadas: $(date)

# MySQL
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
DB_PASSWORD=$DB_PASSWORD

# FTP
FTP_PASSWORD=$FTP_PASSWORD

# Servidor
SERVER_IP=$SERVER_IP

# Opciones
INSTALL_PHPMYADMIN=$INSTALL_PHPMYADMIN
INSTALL_FTP=$INSTALL_FTP

# Dominios
ENVEOF

for i in "${!DOMAINS[@]}"; do
    echo "DOMAIN_$((i+1))=${DOMAINS[$i]}" >> .env
done

# Ajustar permisos y propietario
chown root:root .env        # o ubuntu:ubuntu si usas ese usuario
chmod 600 .env

success "✓ Archivo .env creado con permisos correctos"


echo ""
sleep 2

################################################################################
# 10. COPIAR SCRIPTS AL PROYECTO
################################################################################

banner "═══════════════════════════════════════════════════════════════════════"
banner "  PASO 10: Instalación de scripts de gestión"
banner "═══════════════════════════════════════════════════════════════════════"
echo ""

# Copiar scripts desde el directorio actual al proyecto

pwd
log "Copiando scripts..."
cp "$SCRIPT_DIR"/scripts/{generate-config.sh,setup.sh,setup-ssl.sh,backup.sh} scripts/ 2>/dev/null || {
    warning "Scripts no encontrados en directorio actual, se crearán..."
    # Aquí deberías incluir los scripts inline o desde otro lugar
}

chmod +x scripts/*.sh
success "✓ Scripts instalados"

echo ""
sleep 2

################################################################################
# 11. GENERAR CONFIGURACIONES
################################################################################

banner "═══════════════════════════════════════════════════════════════════════"
banner "  PASO 11: Generación de archivos de configuración"
banner "═══════════════════════════════════════════════════════════════════════"
echo ""

# Limpiar configuraciones antiguas de Nginx si existen
if [ -d "nginx/conf.d" ]; then
    if ls nginx/conf.d/*.conf 1> /dev/null 2>&1; then
        log "Limpiando archivos de configuración antiguos de Nginx..."
        rm -f nginx/conf.d/*.conf 2>/dev/null || true
        rm -f nginx/conf.d/*.backup* 2>/dev/null || true
        success "✓ Configuraciones antiguas eliminadas"
    fi
fi


log "Ejecutando generador de configuraciones..."
./scripts/generate-config.sh || error "Error al generar configuraciones"
success "✓ Configuraciones generadas"

echo ""
sleep 2

################################################################################
# 12. INSTALACIÓN DE WORDPRESS
################################################################################

banner "═══════════════════════════════════════════════════════════════════════"
banner "  PASO 12: Descarga e instalación de WordPress"
banner "═══════════════════════════════════════════════════════════════════════"
echo ""

log "Ejecutando setup de WordPress..."
./scripts/setup.sh || error "Error en setup de WordPress"
success "✓ WordPress instalado y contenedores iniciados"

echo ""
sleep 2

################################################################################
# 13. CONFIGURAR BACKUP AUTOMÁTICO (OPCIONAL)
################################################################################

if [[ $SETUP_CRON == true ]]; then
    banner "═══════════════════════════════════════════════════════════════════════"
    banner "  PASO 13: Configuración de backup automático"
    banner "═══════════════════════════════════════════════════════════════════════"
    echo ""

    log "Configurando cron para backup diario..."
    CRON_CMD="0 2 * * * cd $INSTALL_DIR && ./scripts/backup.sh >> $INSTALL_DIR/logs/backup.log 2>&1"
    (crontab -l 2>/dev/null | grep -v "backup.sh"; echo "$CRON_CMD") | crontab -
    success "✓ Backup automático configurado (diario a las 2:00 AM)"

    echo ""
    sleep 2
fi

################################################################################
# 14. RESUMEN FINAL
################################################################################

clear
banner "╔═══════════════════════════════════════════════════════════════════════╗"
banner "║                                                                       ║"
banner "║                   ✓ INSTALACIÓN COMPLETADA ✓                         ║"
banner "║                                                                       ║"
banner "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""

success "Instalación completada exitosamente en: $INSTALL_DIR"
echo ""

info "═══ INFORMACIÓN DEL SISTEMA ═══"
echo ""
echo "  Directorio del proyecto: $INSTALL_DIR"
echo "  Log de instalación: $LOG_FILE"
echo "  IP del servidor: $SERVER_IP"
echo "  Número de sitios: ${#DOMAINS[@]}"
echo ""

info "═══ CREDENCIALES (¡GUÁRDALAS!) ═══"
echo ""
echo "  MySQL Root: root / $MYSQL_ROOT_PASSWORD"
echo "  MySQL User: wpuser / $DB_PASSWORD"
if [[ $INSTALL_FTP == true ]]; then
    echo "  FTP: ftpuser / $FTP_PASSWORD"
fi
echo ""
warning "  Las credenciales también están en: $CREDENTIALS_FILE"
echo ""

info "═══ SITIOS CONFIGURADOS ═══"
echo ""
for i in "${!DOMAINS[@]}"; do
    echo "  $((i+1)). ${DOMAINS[$i]}"
    echo "     URL: http://${DOMAINS[$i]}"
    echo "     Directorio: $INSTALL_DIR/www/sitio$((i+1))"
    echo ""
done

info "═══ PRÓXIMOS PASOS ═══"
echo ""
echo "  1. Apunta los DNS de tus dominios a: $SERVER_IP"
echo ""
echo "  2. Espera a que los DNS se propaguen (puede tardar hasta 24h)"
echo ""
echo "  3. Obtén certificados SSL:"
echo "     cd $INSTALL_DIR"
echo "     sudo ./scripts/setup-ssl.sh"
echo ""
echo "  4. Completa la instalación de WordPress visitando cada sitio:"
for DOMAIN in "${DOMAINS[@]}"; do
    echo "     - http://$DOMAIN/wp-admin/install.php"
done
echo ""

info "═══ COMANDOS ÚTILES ═══"
echo ""
echo "  Ver estado: cd $INSTALL_DIR && docker compose ps"
echo "  Ver logs: cd $INSTALL_DIR && docker compose logs -f"
echo "  Reiniciar: cd $INSTALL_DIR && docker compose restart"
echo "  Detener: cd $INSTALL_DIR && docker compose stop"
echo "  Iniciar: cd $INSTALL_DIR && docker compose start"
echo "  Backup: cd $INSTALL_DIR && ./scripts/backup.sh"
echo ""

if [[ $INSTALL_PHPMYADMIN == true ]]; then
    info "═══ PHPMYADMIN ═══"
    echo ""
    echo "  Accede a phpMyAdmin desde cualquier sitio en:"
    echo "  http://${DOMAINS[0]}/phpmyadmin"
    echo ""
fi

success "¡Todo listo! Tu plataforma WordPress multi-sitio está funcionando."
echo ""