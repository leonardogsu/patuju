#!/bin/bash

################################################################################
# Script de Setup - Descarga WordPress y configura sitios
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

log "═══════════════════════════════════════════════════"
log "SETUP DE WORDPRESS MULTI-SITE"
log "═══════════════════════════════════════════════════"
echo ""

################################################################################
# 1. DESCARGAR WORDPRESS
################################################################################

log "Paso 1: Descargando WordPress..."

if [ ! -f /tmp/latest.tar.gz ]; then
    wget -q https://wordpress.org/latest.tar.gz -O /tmp/latest.tar.gz || error "Error al descargar WordPress"
    log "✓ WordPress descargado"
else
    log "✓ WordPress ya descargado"
fi

################################################################################
# 2. EXTRAER Y CONFIGURAR SITIOS
################################################################################

log "Paso 2: Configurando sitios..."

# Obtener dominios
DOMAINS=($(grep "^DOMAIN_" .env | cut -d'=' -f2))

for i in "${!DOMAINS[@]}"; do
    SITE_NUM=$((i + 1))
    DOMAIN="${DOMAINS[$i]}"
    SITE_DIR="www/sitio$SITE_NUM"
    
    log "  Configurando sitio $SITE_NUM: $DOMAIN"
    
    # Crear directorio si no existe
    if [ ! -d "$SITE_DIR" ]; then
        mkdir -p "$SITE_DIR"
        
        # Extraer WordPress
        tar -xzf /tmp/latest.tar.gz -C /tmp/
        cp -r /tmp/wordpress/* "$SITE_DIR/"
        
        log "    ✓ WordPress extraído"
    else
        warning "    Directorio $SITE_DIR ya existe, omitiendo..."
        continue
    fi
    
    # Generar wp-config.php
    log "    Generando wp-config.php..."
    
    # Obtener salt keys
    SALT_KEYS=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)
    
    cat > "$SITE_DIR/wp-config.php" << WPCONFIG
<?php
/**
 * WordPress Configuration
 * Site: $DOMAIN
 * Generated: $(date)
 */

// ** MySQL settings ** //
define('DB_NAME', 'wp_sitio$SITE_NUM');
define('DB_USER', 'wpuser');
define('DB_PASSWORD', '$DB_PASSWORD');
define('DB_HOST', 'mysql');
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', 'utf8mb4_unicode_ci');

// ** Authentication Unique Keys and Salts ** //
$SALT_KEYS

// ** WordPress Database Table prefix ** //
\$table_prefix = 'wp_';

// ** For developers: WordPress debugging mode ** //
define('WP_DEBUG', false);
define('WP_DEBUG_LOG', false);
define('WP_DEBUG_DISPLAY', false);

// ** Additional settings ** //
define('DISALLOW_FILE_EDIT', true);
define('WP_POST_REVISIONS', 5);
define('EMPTY_TRASH_DAYS', 30);
define('WP_MEMORY_LIMIT', '256M');
define('WP_MAX_MEMORY_LIMIT', '512M');

// ** Force HTTPS (uncomment after SSL setup) ** //
// define('FORCE_SSL_ADMIN', true);
// if (isset(\$_SERVER['HTTP_X_FORWARDED_PROTO']) && \$_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
//     \$_SERVER['HTTPS'] = 'on';
// }

/** Absolute path to the WordPress directory. */
if ( !defined('ABSPATH') )
    define('ABSPATH', dirname(__FILE__) . '/');

/** Sets up WordPress vars and included files. */
require_once(ABSPATH . 'wp-settings.php');
WPCONFIG
    
    log "    ✓ wp-config.php generado"
done

# Limpiar
rm -rf /tmp/wordpress

################################################################################
# 3. AJUSTAR PERMISOS
################################################################################

log "Paso 3: Ajustando permisos..."

chown -R www-data:www-data www/
find www/ -type d -exec chmod 755 {} \;
find www/ -type f -exec chmod 644 {} \;

log "✓ Permisos ajustados"

################################################################################
# 4. INICIAR CONTENEDORES
################################################################################

log "Paso 4: Iniciando contenedores Docker..."

# Detener contenedores si están corriendo
if docker compose ps -q 2>/dev/null; then
    log "  Deteniendo contenedores existentes..."
    docker compose down
fi

# Iniciar contenedores
log "  Iniciando contenedores..."
docker compose up -d || error "Error al iniciar contenedores"

log "✓ Contenedores iniciados"

################################################################################
# 5. ESPERAR A QUE MYSQL ESTÉ LISTO
################################################################################

log "Paso 5: Esperando a que MySQL esté listo..."

max_attempts=30
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if docker compose exec -T mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SELECT 1" &>/dev/null; then
        log "✓ MySQL está listo"
        break
    fi
    attempt=$((attempt + 1))
    echo -n "."
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    error "Timeout esperando a MySQL"
fi

echo ""

################################################################################
# 6. MOSTRAR INFORMACIÓN
################################################################################

log "═══════════════════════════════════════════════════"
log "SETUP COMPLETADO EXITOSAMENTE"
log "═══════════════════════════════════════════════════"
echo ""
info "Contenedores en ejecución:"
docker compose ps
echo ""
info "Sitios configurados:"
for i in "${!DOMAINS[@]}"; do
    SITE_NUM=$((i + 1))
    echo "  $((i + 1)). ${DOMAINS[$i]} -> http://${DOMAINS[$i]}"
done
echo ""
info "CREDENCIALES:"
echo "  MySQL Root: root / $MYSQL_ROOT_PASSWORD"
echo "  MySQL User: wpuser / $DB_PASSWORD"
if [ -n "$FTP_PASSWORD" ]; then
    echo "  FTP User: ftpuser / $FTP_PASSWORD"
fi
echo ""
warning "PRÓXIMOS PASOS:"
echo "  1. Apunta los DNS de tus dominios a: $SERVER_IP"
echo "  2. Ejecuta: ./scripts/setup-ssl.sh para obtener certificados SSL"
echo "  3. Completa la instalación de WordPress en cada sitio:"
for DOMAIN in "${DOMAINS[@]}"; do
    echo "     - http://$DOMAIN"
done
echo ""
info "Para ver los logs: docker compose logs -f"
info "Para gestionar: docker compose [start|stop|restart]"
echo ""
