#!/bin/bash

################################################################################
# Script de Diagnóstico - WordPress Multi-Site
# Verifica el estado de MySQL, bases de datos y conexiones
################################################################################

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[✓]${NC} $1"
}

info() {
    echo -e "${BLUE}[ℹ]${NC} $1"
}

error() {
    echo -e "${RED}[✗]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

title() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Cargar variables
if [ ! -f .env ]; then
    error "Archivo .env no encontrado"
    exit 1
fi

source .env

clear
cat << 'EOF'
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║          DIAGNÓSTICO - WordPress Multi-Site                ║
║              Sistema de Base de Datos                      ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
EOF

echo ""

################################################################################
# 1. VERIFICAR CONTENEDORES
################################################################################

title "1. ESTADO DE CONTENEDORES DOCKER"

info "Verificando contenedores en ejecución..."
echo ""

if docker compose ps --format json >/dev/null 2>&1; then
    docker compose ps
    echo ""
    
    # Verificar cada contenedor
    containers=("mysql" "php" "nginx")
    all_running=true
    
    for container in "${containers[@]}"; do
        if docker compose ps "$container" --format json 2>/dev/null | grep -q '"State":"running"'; then
            log "Contenedor $container está corriendo"
        else
            error "Contenedor $container NO está corriendo"
            all_running=false
        fi
    done
    
    echo ""
    
    if [ "$all_running" = true ]; then
        log "Todos los contenedores necesarios están corriendo"
    else
        error "Algunos contenedores no están corriendo. Ejecuta: docker compose up -d"
    fi
else
    error "No se pudo conectar con Docker Compose"
    echo "Verifica que estés en el directorio correcto y que Docker esté funcionando"
    exit 1
fi

################################################################################
# 2. VERIFICAR MYSQL HEALTHCHECK
################################################################################

title "2. HEALTHCHECK DE MYSQL"

info "Verificando estado de salud de MySQL..."
echo ""

health_status=$(docker compose ps mysql --format json 2>/dev/null | grep -o '"Health":"[^"]*"' | cut -d'"' -f4 || echo "unknown")

case "$health_status" in
    "healthy")
        log "MySQL healthcheck: ${GREEN}HEALTHY${NC}"
        ;;
    "unhealthy")
        error "MySQL healthcheck: ${RED}UNHEALTHY${NC}"
        warning "MySQL tiene problemas. Revisa los logs: docker compose logs mysql"
        ;;
    "starting")
        warning "MySQL healthcheck: ${YELLOW}STARTING${NC}"
        info "MySQL aún está iniciando. Espera unos segundos y vuelve a ejecutar este script"
        ;;
    *)
        warning "MySQL healthcheck: ${YELLOW}UNKNOWN${NC}"
        info "No se pudo determinar el estado de salud"
        ;;
esac

################################################################################
# 3. VERIFICAR CONEXIÓN A MYSQL
################################################################################

title "3. CONEXIÓN A MYSQL"

info "Probando conexión como root..."
echo ""

if docker compose exec -T mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SELECT 'Conexión exitosa' AS status;" 2>/dev/null | grep -q "Conexión exitosa"; then
    log "Conexión como root: ${GREEN}OK${NC}"
else
    error "No se pudo conectar como root"
    warning "Verifica la contraseña MYSQL_ROOT_PASSWORD en .env"
    exit 1
fi

info "Probando conexión como wpuser..."
echo ""

if docker compose exec -T mysql mysql -uwpuser -p"$DB_PASSWORD" -e "SELECT 'Conexión exitosa' AS status;" 2>/dev/null | grep -q "Conexión exitosa"; then
    log "Conexión como wpuser: ${GREEN}OK${NC}"
else
    error "No se pudo conectar como wpuser"
    warning "Verifica la contraseña DB_PASSWORD en .env"
fi

################################################################################
# 4. LISTAR BASES DE DATOS
################################################################################

title "4. BASES DE DATOS EXISTENTES"

info "Listando todas las bases de datos..."
echo ""

databases=$(docker compose exec -T mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -N -e "SHOW DATABASES;" 2>/dev/null || echo "")

if [ -n "$databases" ]; then
    echo "$databases" | while read db; do
        if [[ "$db" == wp_sitio* ]]; then
            log "Base de datos: ${GREEN}$db${NC}"
        else
            info "Base de datos: $db"
        fi
    done
else
    error "No se pudieron listar las bases de datos"
fi

################################################################################
# 5. VERIFICAR BASES DE DATOS WORDPRESS
################################################################################

title "5. VERIFICACIÓN DE BASES DE DATOS WORDPRESS"

# Obtener dominios
DOMAINS=($(grep "^DOMAIN_" .env | cut -d'=' -f2))

info "Verificando bases de datos para ${#DOMAINS[@]} sitios..."
echo ""

all_dbs_ok=true

for i in "${!DOMAINS[@]}"; do
    SITE_NUM=$((i + 1))
    DOMAIN="${DOMAINS[$i]}"
    DB_NAME="wp_sitio$SITE_NUM"
    
    echo -e "${BLUE}Sitio $SITE_NUM:${NC} $DOMAIN (base de datos: $DB_NAME)"
    
    # Verificar si existe
    if docker compose exec -T mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "USE $DB_NAME;" 2>/dev/null; then
        log "  Base de datos existe: ${GREEN}✓${NC}"
        
        # Contar tablas
        table_count=$(docker compose exec -T mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DB_NAME';" 2>/dev/null || echo "0")
        info "  Número de tablas: $table_count"
        
        # Verificar permisos de wpuser
        if docker compose exec -T mysql mysql -uwpuser -p"$DB_PASSWORD" -e "USE $DB_NAME; SELECT 1;" 2>/dev/null >/dev/null; then
            log "  Permisos de wpuser: ${GREEN}OK${NC}"
        else
            error "  Permisos de wpuser: ${RED}FALLO${NC}"
            warning "  wpuser no puede acceder a $DB_NAME"
            all_dbs_ok=false
        fi
    else
        error "  Base de datos NO existe: ${RED}✗${NC}"
        warning "  Necesitas crear la base de datos: $DB_NAME"
        all_dbs_ok=false
    fi
    echo ""
done

if [ "$all_dbs_ok" = true ]; then
    log "Todas las bases de datos están configuradas correctamente"
else
    error "Algunas bases de datos tienen problemas"
    echo ""
    warning "Para corregir, ejecuta:"
    echo "  docker compose exec mysql mysql -uroot -p\$MYSQL_ROOT_PASSWORD"
    echo "  Y ejecuta los siguientes comandos SQL:"
    for i in "${!DOMAINS[@]}"; do
        SITE_NUM=$((i + 1))
        echo "  CREATE DATABASE IF NOT EXISTS wp_sitio$SITE_NUM CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
        echo "  GRANT ALL PRIVILEGES ON wp_sitio$SITE_NUM.* TO 'wpuser'@'%';"
    done
    echo "  FLUSH PRIVILEGES;"
fi

################################################################################
# 6. VERIFICAR PERMISOS DEL USUARIO
################################################################################

title "6. PERMISOS DEL USUARIO WPUSER"

info "Listando permisos de wpuser..."
echo ""

grants=$(docker compose exec -T mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SHOW GRANTS FOR 'wpuser'@'%';" 2>/dev/null || echo "")

if [ -n "$grants" ]; then
    echo "$grants"
    echo ""
    
    # Verificar si tiene permisos en las bases correctas
    all_grants_ok=true
    for i in "${!DOMAINS[@]}"; do
        SITE_NUM=$((i + 1))
        DB_NAME="wp_sitio$SITE_NUM"
        
        if echo "$grants" | grep -q "$DB_NAME"; then
            log "Tiene permisos en: $DB_NAME"
        else
            error "NO tiene permisos en: $DB_NAME"
            all_grants_ok=false
        fi
    done
    
    echo ""
    
    if [ "$all_grants_ok" = true ]; then
        log "Todos los permisos están configurados correctamente"
    else
        error "Faltan algunos permisos"
    fi
else
    error "No se pudieron listar los permisos"
fi

################################################################################
# 7. PROBAR CONEXIÓN DESDE PHP
################################################################################

title "7. PRUEBA DE CONEXIÓN DESDE PHP"

info "Probando conexión desde el contenedor PHP..."
echo ""

all_connections_ok=true

for i in "${!DOMAINS[@]}"; do
    SITE_NUM=$((i + 1))
    DOMAIN="${DOMAINS[$i]}"
    DB_NAME="wp_sitio$SITE_NUM"
    
    echo -e "${BLUE}Sitio $SITE_NUM:${NC} $DOMAIN"
    
    # Crear script de prueba temporal
    test_result=$(docker compose exec -T php php -r "
        \$host = 'mysql';
        \$user = 'wpuser';
        \$pass = '$DB_PASSWORD';
        \$dbname = '$DB_NAME';
        
        try {
            \$conn = new mysqli(\$host, \$user, \$pass, \$dbname);
            if (\$conn->connect_error) {
                echo 'ERROR: ' . \$conn->connect_error;
            } else {
                echo 'OK';
            }
            \$conn->close();
        } catch (Exception \$e) {
            echo 'ERROR: ' . \$e->getMessage();
        }
    " 2>&1)
    
    if echo "$test_result" | grep -q "^OK"; then
        log "  Conexión desde PHP: ${GREEN}OK${NC}"
    else
        error "  Conexión desde PHP: ${RED}FALLO${NC}"
        warning "  Error: $test_result"
        all_connections_ok=false
    fi
    echo ""
done

if [ "$all_connections_ok" = true ]; then
    log "Todas las conexiones desde PHP funcionan correctamente"
else
    error "Algunas conexiones desde PHP fallan"
fi

################################################################################
# 8. VERIFICAR ARCHIVOS WP-CONFIG.PHP
################################################################################

title "8. VERIFICACIÓN DE wp-config.php"

info "Verificando configuración de WordPress..."
echo ""

all_configs_ok=true

for i in "${!DOMAINS[@]}"; do
    SITE_NUM=$((i + 1))
    DOMAIN="${DOMAINS[$i]}"
    CONFIG_FILE="www/sitio$SITE_NUM/wp-config.php"
    
    echo -e "${BLUE}Sitio $SITE_NUM:${NC} $DOMAIN"
    
    if [ -f "$CONFIG_FILE" ]; then
        log "  Archivo existe: ${GREEN}✓${NC}"
        
        # Verificar configuración de base de datos
        db_name=$(grep "define('DB_NAME'" "$CONFIG_FILE" | cut -d"'" -f4)
        db_user=$(grep "define('DB_USER'" "$CONFIG_FILE" | cut -d"'" -f4)
        db_host=$(grep "define('DB_HOST'" "$CONFIG_FILE" | cut -d"'" -f4)
        
        info "  DB_NAME: $db_name"
        info "  DB_USER: $db_user"
        info "  DB_HOST: $db_host"
        
        # Verificar que los valores sean correctos
        if [ "$db_name" = "wp_sitio$SITE_NUM" ]; then
            log "  DB_NAME correcto: ${GREEN}✓${NC}"
        else
            error "  DB_NAME incorrecto (esperado: wp_sitio$SITE_NUM, actual: $db_name)"
            all_configs_ok=false
        fi
        
        if [ "$db_user" = "wpuser" ]; then
            log "  DB_USER correcto: ${GREEN}✓${NC}"
        else
            error "  DB_USER incorrecto (esperado: wpuser, actual: $db_user)"
            all_configs_ok=false
        fi
        
        if [ "$db_host" = "mysql" ]; then
            log "  DB_HOST correcto: ${GREEN}✓${NC}"
        else
            error "  DB_HOST incorrecto (esperado: mysql, actual: $db_host)"
            all_configs_ok=false
        fi
    else
        error "  Archivo NO existe: ${RED}✗${NC}"
        warning "  Necesitas ejecutar: ./scripts/setup.sh"
        all_configs_ok=false
    fi
    echo ""
done

if [ "$all_configs_ok" = true ]; then
    log "Todos los archivos wp-config.php están configurados correctamente"
else
    error "Algunos archivos wp-config.php tienen problemas"
fi

################################################################################
# 9. LOGS RECIENTES
################################################################################

title "9. LOGS RECIENTES (ÚLTIMAS 10 LÍNEAS)"

info "Logs de MySQL:"
echo ""
docker compose logs mysql --tail=10 2>/dev/null || echo "No se pudieron obtener logs"

echo ""
info "Logs de PHP:"
echo ""
docker compose logs php --tail=10 2>/dev/null || echo "No se pudieron obtener logs"

################################################################################
# 10. RESUMEN FINAL
################################################################################

title "10. RESUMEN DEL DIAGNÓSTICO"

echo -e "${CYAN}Estado General:${NC}"
echo ""

# Crear resumen
if docker compose ps mysql --format json 2>/dev/null | grep -q '"State":"running"'; then
    log "MySQL está corriendo"
else
    error "MySQL NO está corriendo"
fi

if [ "$health_status" = "healthy" ]; then
    log "MySQL está saludable"
else
    error "MySQL tiene problemas de salud"
fi

if [ "$all_dbs_ok" = true ]; then
    log "Todas las bases de datos están OK"
else
    error "Hay problemas con las bases de datos"
fi

if [ "$all_connections_ok" = true ]; then
    log "Todas las conexiones PHP están OK"
else
    error "Hay problemas de conexión desde PHP"
fi

if [ "$all_configs_ok" = true ]; then
    log "Todos los wp-config.php están OK"
else
    error "Hay problemas en los archivos wp-config.php"
fi

echo ""

if [ "$all_dbs_ok" = true ] && [ "$all_connections_ok" = true ] && [ "$all_configs_ok" = true ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                            ║${NC}"
    echo -e "${GREEN}║              ✓ TODOS LOS TESTS PASARON ✓                  ║${NC}"
    echo -e "${GREEN}║                                                            ║${NC}"
    echo -e "${GREEN}║     El sistema está configurado correctamente y           ║${NC}"
    echo -e "${GREEN}║     WordPress debería funcionar sin problemas.             ║${NC}"
    echo -e "${GREEN}║                                                            ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
else
    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                                                            ║${NC}"
    echo -e "${RED}║              ✗ SE ENCONTRARON PROBLEMAS ✗                 ║${NC}"
    echo -e "${RED}║                                                            ║${NC}"
    echo -e "${RED}║     Revisa los errores marcados arriba y sigue las        ║${NC}"
    echo -e "${RED}║     recomendaciones para corregirlos.                      ║${NC}"
    echo -e "${RED}║                                                            ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
fi

echo ""
info "Para más ayuda, revisa: CORRECCIONES-DATABASE-CONNECTION.md"
echo ""
