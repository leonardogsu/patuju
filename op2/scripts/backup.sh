#!/bin/bash

################################################################################
# Script de Backup Automático
# Realiza backup de bases de datos MySQL y archivos WordPress
################################################################################

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Cargar variables
if [ ! -f .env ]; then
    error "Archivo .env no encontrado"
fi

source .env

# Configuración
BACKUP_DIR="backups"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

log "═══════════════════════════════════════════════════"
log "BACKUP AUTOMÁTICO - $(date)"
log "═══════════════════════════════════════════════════"
echo ""

# Crear directorio de backup
mkdir -p "$BACKUP_DIR/$DATE"

################################################################################
# 1. BACKUP DE BASES DE DATOS
################################################################################

log "Paso 1: Backup de bases de datos MySQL..."

# Obtener lista de dominios
DOMAINS=($(grep "^DOMAIN_" .env | cut -d'=' -f2))

for i in "${!DOMAINS[@]}"; do
    SITE_NUM=$((i + 1))
    DB_NAME="wp_sitio$SITE_NUM"
    DOMAIN="${DOMAINS[$i]}"
    
    log "  Respaldando base de datos: $DB_NAME ($DOMAIN)"
    
    docker compose exec -T mysql mysqldump \
        -uroot \
        -p"$MYSQL_ROOT_PASSWORD" \
        "$DB_NAME" \
        --single-transaction \
        --quick \
        --lock-tables=false \
        > "$BACKUP_DIR/$DATE/${DB_NAME}.sql" \
        || warning "    Error al respaldar $DB_NAME"
    
    if [ -f "$BACKUP_DIR/$DATE/${DB_NAME}.sql" ]; then
        # Comprimir
        gzip "$BACKUP_DIR/$DATE/${DB_NAME}.sql"
        log "    ✓ Backup completado: ${DB_NAME}.sql.gz"
    fi
done

################################################################################
# 2. BACKUP DE ARCHIVOS WORDPRESS
################################################################################

log "Paso 2: Backup de archivos WordPress..."

for i in "${!DOMAINS[@]}"; do
    SITE_NUM=$((i + 1))
    DOMAIN="${DOMAINS[$i]}"
    SITE_DIR="www/sitio$SITE_NUM"
    
    if [ ! -d "$SITE_DIR" ]; then
        warning "  Directorio $SITE_DIR no existe, omitiendo..."
        continue
    fi
    
    log "  Respaldando archivos: $DOMAIN"
    
    # Backup de wp-content (contiene uploads, temas, plugins)
    tar -czf "$BACKUP_DIR/$DATE/sitio${SITE_NUM}_files.tar.gz" \
        -C "$SITE_DIR" \
        wp-content \
        2>/dev/null || warning "    Error al respaldar archivos de $DOMAIN"
    
    if [ -f "$BACKUP_DIR/$DATE/sitio${SITE_NUM}_files.tar.gz" ]; then
        log "    ✓ Backup completado: sitio${SITE_NUM}_files.tar.gz"
    fi
done

################################################################################
# 3. BACKUP DE CONFIGURACIONES
################################################################################

log "Paso 3: Backup de configuraciones..."

tar -czf "$BACKUP_DIR/$DATE/config.tar.gz" \
    .env \
    docker-compose.yml \
    nginx/ \
    php/ \
    mysql/my.cnf \
    mysql/init/ \
    2>/dev/null || warning "  Error al respaldar configuraciones"

if [ -f "$BACKUP_DIR/$DATE/config.tar.gz" ]; then
    log "  ✓ Configuraciones respaldadas"
fi

################################################################################
# 4. CREAR ARCHIVO DE INFORMACIÓN
################################################################################

cat > "$BACKUP_DIR/$DATE/backup_info.txt" << INFOEOF
Backup Information
==================
Date: $(date)
Server IP: $SERVER_IP
Number of sites: ${#DOMAINS[@]}

Sites backed up:
INFOEOF

for i in "${!DOMAINS[@]}"; do
    SITE_NUM=$((i + 1))
    echo "  $SITE_NUM. ${DOMAINS[$i]} (wp_sitio$SITE_NUM)" >> "$BACKUP_DIR/$DATE/backup_info.txt"
done

################################################################################
# 5. LIMPIAR BACKUPS ANTIGUOS
################################################################################

log "Paso 4: Limpiando backups antiguos (>${RETENTION_DAYS} días)..."

OLD_BACKUPS=$(find "$BACKUP_DIR" -maxdepth 1 -type d -mtime +$RETENTION_DAYS 2>/dev/null || true)

if [ -n "$OLD_BACKUPS" ]; then
    echo "$OLD_BACKUPS" | while read -r backup; do
        if [ "$backup" != "$BACKUP_DIR" ]; then
            log "  Eliminando: $(basename $backup)"
            rm -rf "$backup"
        fi
    done
else
    log "  No hay backups antiguos para eliminar"
fi

################################################################################
# 6. CALCULAR TAMAÑO Y RESUMEN
################################################################################

BACKUP_SIZE=$(du -sh "$BACKUP_DIR/$DATE" | awk '{print $1}')
TOTAL_SIZE=$(du -sh "$BACKUP_DIR" | awk '{print $1}')

echo ""
log "═══════════════════════════════════════════════════"
log "BACKUP COMPLETADO EXITOSAMENTE"
log "═══════════════════════════════════════════════════"
echo ""
info "Ubicación: $BACKUP_DIR/$DATE"
info "Tamaño del backup: $BACKUP_SIZE"
info "Tamaño total de backups: $TOTAL_SIZE"
echo ""
info "Contenido del backup:"
ls -lh "$BACKUP_DIR/$DATE/" | tail -n +2 | awk '{print "  " $9 " (" $5 ")"}'
echo ""
info "Para restaurar un backup, consulta la documentación"
echo ""

# Opcional: Enviar backup a ubicación remota
# Descomenta y configura según necesites:
# log "Enviando backup a servidor remoto..."
# scp -r "$BACKUP_DIR/$DATE" usuario@servidor:/ruta/backups/
# log "✓ Backup enviado al servidor remoto"
