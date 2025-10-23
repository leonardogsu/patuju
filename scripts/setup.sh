#!/bin/bash

################################################################################
# Script de Setup - Descarga WordPress y configura sitios
# VERSIÓN CORREGIDA - Mejora la espera de MySQL y verifica las bases de datos
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

chown -R www-data:www-data www/ 2>/dev/null || chown -R 33:33 www/
find www/ -type d -exec chmod 755 {} \;
find www/ -type f -exec chmod 644 {} \;

log "✓ Permisos ajustados"

################################################################################
# 4. INICIAR CONTENEDORES
################################################################################

log "Paso 4: Iniciando contenedores Docker..."

# Detener contenedores si están corriendo
if docker compose ps -q 2>/dev/null | grep -q .; then
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

# Espera a que el healthcheck de MySQL sea exitoso
log "Esperando healthcheck de MySQL..."
max_attempts=90
attempt=0

while [ $attempt -lt $max_attempts ]; do
    # Verificar si el healthcheck es exitoso
    health_status=$(docker compose ps mysql --format json 2>/dev/null | grep -o '"Health":"[^"]*"' | cut -d'"' -f4 || echo "")

    if [ "$health_status" = "healthy" ]; then
        log "✅ MySQL está listo (healthcheck: healthy)"
        break
    fi

    attempt=$((attempt + 1))

    if [ $((attempt % 10)) -eq 0 ]; then
        log "DEBUG: Intento $attempt de $max_attempts. Estado: $health_status"
    fi

    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    error "❌ Timeout esperando a MySQL. Verifica logs con: docker compose logs mysql"
fi

# Espera adicional para asegurar que los scripts de inicialización se ejecutaron
log "Esperando a que se completen los scripts de inicialización..."
sleep 5

################################################################################
# 6. VERIFICAR BASES DE DATOS
################################################################################

log "Paso 6: Verificando bases de datos..."

for i in "${!DOMAINS[@]}"; do
    SITE_NUM=$((i + 1))
    DB_NAME="wp_sitio$SITE_NUM"

    log "  Verificando base de datos: $DB_NAME"

    # Intentar crear la base de datos si no existe
    docker compose exec -T mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null || {
        warning "    No se pudo verificar/crear $DB_NAME"
        continue
    }

    # Otorgar permisos
    docker compose exec -T mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO 'wpuser'@'%'; FLUSH PRIVILEGES;" 2>/dev/null || {
        warning "    No se pudieron otorgar permisos para $DB_NAME"
        continue
    }

    log "    ✓ Base de datos $DB_NAME verificada y accesible"
done

################################################################################
# 7. VERIFICAR CONEXIÓN DESDE PHP
################################################################################

log "Paso 7: Verificando conexión desde contenedor PHP..."

for i in "${!DOMAINS[@]}"; do
    SITE_NUM=$((i + 1))
    DB_NAME="wp_sitio$SITE_NUM"

    # Crear un script PHP temporal para probar la conexión
    TEST_SCRIPT="www/sitio$SITE_NUM/test-db-connection.php"
    cat > "$TEST_SCRIPT" << 'TESTPHP'
<?php
$host = 'mysql';
$user = 'wpuser';
$pass = getenv('DB_PASSWORD') ?: '$DB_PASSWORD';
$dbname = '$DB_NAME';

try {
    $conn = new mysqli($host, $user, $pass, $dbname);
    if ($conn->connect_error) {
        echo "ERROR: " . $conn->connect_error;
        exit(1);
    }
    echo "OK";
    $conn->close();
} catch (Exception $e) {
    echo "ERROR: " . $e->getMessage();
    exit(1);
}
?>
TESTPHP

    # Reemplazar las variables en el script
    sed -i "s/\$DB_PASSWORD/$DB_PASSWORD/g" "$TEST_SCRIPT"
    sed -i "s/\$DB_NAME/$DB_NAME/g" "$TEST_SCRIPT"

    # Ejecutar el test desde el contenedor PHP
    result=$(docker compose exec -T php php "/var/www/html/sitio$SITE_NUM/test-db-connection.php" 2>&1 || echo "ERROR")

    if echo "$result" | grep -q "^OK"; then
        log "    ✓ Conexión exitosa desde PHP a $DB_NAME"
    else
        warning "    ⚠ Problema de conexión a $DB_NAME: $result"
    fi

    # Eliminar script de prueba
    rm -f "$TEST_SCRIPT"
done

################################################################################
# 8. MOSTRAR INFORMACIÓN
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
    echo "      Base de datos: wp_sitio$SITE_NUM"
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
    echo "     - http://$DOMAIN/wp-admin/install.php"
done
echo ""
info "DIAGNÓSTICO:"
echo "  - Ver logs de MySQL: docker compose logs mysql"
echo "  - Ver logs de PHP: docker compose logs php"
echo "  - Acceder a MySQL: docker compose exec mysql mysql -uroot -p$MYSQL_ROOT_PASSWORD"
echo "  - Listar bases de datos: docker compose exec mysql mysql -uroot -p$MYSQL_ROOT_PASSWORD -e 'SHOW DATABASES;'"
echo ""
info "Para gestionar: docker compose [start|stop|restart|logs]"
echo ""