#!/bin/bash

################################################################################
# Script de Diagnóstico - WordPress Multi-Site
# Verifica el estado de MySQL, bases de datos, Nginx y phpMyAdmin
# VERSIÓN MEJORADA - Con verificación completa de Nginx y phpMyAdmin
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
║       Sistema Completo: DB + Nginx + phpMyAdmin           ║
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

    # Verificar phpMyAdmin si está habilitado
    if grep -q "INSTALL_PHPMYADMIN=true" .env 2>/dev/null; then
        if docker compose ps "phpmyadmin" --format json 2>/dev/null | grep -q '"State":"running"'; then
            log "Contenedor phpmyadmin está corriendo"
        else
            error "Contenedor phpmyadmin NO está corriendo"
            all_running=false
        fi
    fi

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
# 10. RESUMEN MYSQL
################################################################################

title "10. RESUMEN DE MYSQL Y BASES DE DATOS"

echo -e "${CYAN}Estado General de MySQL:${NC}"
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

################################################################################
# 11. CONFIGURACIÓN DE NGINX
################################################################################

title "11. CONFIGURACIÓN DE NGINX"

info "Verificando contenedor nginx..."
echo ""

nginx_running=false
nginx_config_valid=false
all_vhosts_ok=true

# 11.1 - Estado del contenedor
if docker compose ps nginx --format json 2>/dev/null | grep -q '"State":"running"'; then
    log "Contenedor nginx está corriendo"
    nginx_running=true

    # Verificar puertos
    ports=$(docker compose ps nginx --format json 2>/dev/null | grep -o '"PublishedPort":[0-9]*' | cut -d':' -f2 | tr '\n' ' ')
    if echo "$ports" | grep -q "80"; then
        log "Puerto 80 expuesto: ${GREEN}✓${NC}"
    else
        error "Puerto 80 NO expuesto"
    fi
    if echo "$ports" | grep -q "443"; then
        log "Puerto 443 expuesto: ${GREEN}✓${NC}"
    else
        warning "Puerto 443 NO expuesto (normal si no hay SSL)"
    fi
else
    error "Contenedor nginx NO está corriendo"
    nginx_running=false
fi

echo ""

# 11.2 - Archivos de configuración
info "Verificando configuración principal..."
echo ""

if [ -f "nginx/nginx.conf" ]; then
    log "nginx.conf existe: ${GREEN}✓${NC}"
else
    error "nginx.conf NO existe: ${RED}✗${NC}"
    all_vhosts_ok=false
fi

# Validar sintaxis si nginx está corriendo
if [ "$nginx_running" = true ]; then
    if docker compose exec nginx nginx -t 2>&1 | grep -q "syntax is ok"; then
        log "Configuración de nginx es válida: ${GREEN}✓${NC}"
        nginx_config_valid=true
    else
        error "Configuración de nginx tiene errores: ${RED}✗${NC}"
        warning "Ejecuta: docker compose exec nginx nginx -t"
        nginx_config_valid=false
        all_vhosts_ok=false
    fi
fi

echo ""

# 11.3 - Virtual Hosts detectados
info "Verificando virtual hosts..."
echo ""

vhost_count=0
for i in "${!DOMAINS[@]}"; do
    SITE_NUM=$((i + 1))
    DOMAIN="${DOMAINS[$i]}"
    CONFIG_FILE="nginx/conf.d/${DOMAIN}.conf"

    echo -e "${BLUE}Sitio $SITE_NUM:${NC} $DOMAIN"

    if [ -f "$CONFIG_FILE" ]; then
        log "  Archivo de configuración existe: ${GREEN}✓${NC}"
        vhost_count=$((vhost_count + 1))

        # Extraer información clave
        server_name=$(grep "server_name" "$CONFIG_FILE" | head -1 | sed 's/.*server_name\s*\(.*\);/\1/' | xargs)
        root_path=$(grep "root /var/www/html" "$CONFIG_FILE" | head -1 | sed 's/.*root\s*\(.*\);/\1/' | xargs)
        fastcgi_pass=$(grep "fastcgi_pass" "$CONFIG_FILE" | head -1 | sed 's/.*fastcgi_pass\s*\(.*\);/\1/' | xargs)

        info "  server_name: $server_name"
        info "  root: $root_path"
        info "  fastcgi_pass: $fastcgi_pass"

        # Verificar HTTP
        if grep -q "listen 80" "$CONFIG_FILE" && ! grep -q "^[[:space:]]*#.*listen 80" "$CONFIG_FILE"; then
            log "  HTTP (puerto 80): ${GREEN}✓ activo${NC}"
        else
            warning "  HTTP (puerto 80): ${YELLOW}✗ deshabilitado${NC}"
        fi

        # Verificar HTTPS
        https_commented=$(grep -c "^[[:space:]]*#.*listen 443" "$CONFIG_FILE" 2>/dev/null || echo "0")
        https_active=$(grep -c "^[[:space:]]*listen 443" "$CONFIG_FILE" 2>/dev/null || echo "0")

        if [ "$https_active" -gt 0 ]; then
            log "  HTTPS (puerto 443): ${GREEN}✓ activo${NC}"

            # Verificar certificados SSL
            ssl_cert=$(grep "ssl_certificate " "$CONFIG_FILE" | grep -v "ssl_certificate_key" | head -1 | sed 's/.*ssl_certificate\s*\(.*\);/\1/' | xargs)
            if [ -n "$ssl_cert" ]; then
                # Quitar el prefijo /etc/letsencrypt y verificar en certbot/conf
                cert_file=$(echo "$ssl_cert" | sed 's|/etc/letsencrypt|certbot/conf|')
                if [ -f "$cert_file" ]; then
                    log "  Certificado SSL: ${GREEN}✓ existe${NC}"
                    # Obtener fecha de expiración
                    expiry=$(openssl x509 -enddate -noout -in "$cert_file" 2>/dev/null | cut -d= -f2 || echo "")
                    if [ -n "$expiry" ]; then
                        info "  Expira: $expiry"
                    fi
                else
                    error "  Certificado SSL: ${RED}✗ no encontrado${NC}"
                fi
            fi
        elif [ "$https_commented" -gt 0 ]; then
            warning "  HTTPS (puerto 443): ${YELLOW}✗ comentado${NC}"
        else
            warning "  HTTPS (puerto 443): ${YELLOW}✗ no configurado${NC}"
        fi

        # Verificar phpMyAdmin si está habilitado
        if grep -q "INSTALL_PHPMYADMIN=true" .env 2>/dev/null; then
            if grep -q "location.*phpmyadmin" "$CONFIG_FILE"; then
                log "  phpMyAdmin: ${GREEN}✓ configurado${NC}"
            else
                warning "  phpMyAdmin: ${YELLOW}✗ no configurado${NC}"
            fi
        fi

        # Validar que server_name coincida
        if echo "$server_name" | grep -q "$DOMAIN"; then
            log "  server_name coincide: ${GREEN}✓${NC}"
        else
            error "  server_name NO coincide (esperado: $DOMAIN, actual: $server_name)"
            all_vhosts_ok=false
        fi

        # Validar root path
        expected_root="/var/www/html/sitio$SITE_NUM"
        if [ "$root_path" = "$expected_root" ]; then
            log "  root path correcto: ${GREEN}✓${NC}"
        else
            error "  root path incorrecto (esperado: $expected_root, actual: $root_path)"
            all_vhosts_ok=false
        fi

        # Validar fastcgi_pass
        if [ "$fastcgi_pass" = "php:9000" ]; then
            log "  fastcgi_pass correcto: ${GREEN}✓${NC}"
        else
            error "  fastcgi_pass incorrecto (esperado: php:9000, actual: $fastcgi_pass)"
            all_vhosts_ok=false
        fi

    else
        error "  Archivo de configuración NO existe: ${RED}✗${NC}"
        warning "  Necesitas ejecutar: ./scripts/generate-config.sh"
        all_vhosts_ok=false
    fi
    echo ""
done

log "Virtual hosts configurados: $vhost_count/${#DOMAINS[@]}"
echo ""

# 11.4 - Pruebas de conectividad
if [ "$nginx_running" = true ] && [ "$nginx_config_valid" = true ]; then
    info "Probando conectividad HTTP..."
    echo ""

    for DOMAIN in "${DOMAINS[@]}"; do
        # Probar desde localhost
        response=$(docker compose exec -T nginx sh -c "curl -s -o /dev/null -w '%{http_code}' http://localhost 2>/dev/null" || echo "000")
        if [ "$response" = "200" ] || [ "$response" = "301" ] || [ "$response" = "302" ]; then
            log "  localhost responde: ${GREEN}$response${NC}"
        else
            warning "  localhost responde: ${YELLOW}$response${NC}"
        fi
    done
    echo ""
fi

# 11.5 - Logs de nginx
info "Logs recientes de nginx (últimas 10 líneas):"
echo ""
nginx_logs=$(docker compose logs nginx --tail=10 2>/dev/null || echo "")
if [ -n "$nginx_logs" ]; then
    echo "$nginx_logs" | tail -10
    echo ""

    # Verificar errores críticos
    error_count=$(echo "$nginx_logs" | grep -ic "error" || echo "0")
    if [ "$error_count" -gt 0 ]; then
        warning "Se encontraron $error_count líneas con 'error' en los logs"
    else
        log "No se detectaron errores críticos en los logs recientes"
    fi
else
    warning "No se pudieron obtener logs de nginx"
fi

echo ""

################################################################################
# 12. CONFIGURACIÓN DE PHPMYADMIN
################################################################################

title "12. CONFIGURACIÓN DE PHPMYADMIN"

phpmyadmin_enabled=false
phpmyadmin_running=false
phpmyadmin_config_ok=true
phpmyadmin_accessible=true

# Verificar si phpMyAdmin está habilitado
if grep -q "INSTALL_PHPMYADMIN=true" .env 2>/dev/null; then
    phpmyadmin_enabled=true
    log "phpMyAdmin está habilitado en .env"
    echo ""
else
    info "phpMyAdmin NO está habilitado en .env"
    info "Para habilitarlo, configura INSTALL_PHPMYADMIN=true en .env"
    echo ""
fi

if [ "$phpmyadmin_enabled" = true ]; then

    # 12.1 - Estado del contenedor
    info "Verificando contenedor phpmyadmin..."
    echo ""

    if docker compose ps phpmyadmin --format json 2>/dev/null | grep -q '"State":"running"'; then
        log "Contenedor phpmyadmin está corriendo: ${GREEN}✓${NC}"
        phpmyadmin_running=true
    else
        error "Contenedor phpmyadmin NO está corriendo: ${RED}✗${NC}"
        warning "Ejecuta: docker compose up -d phpmyadmin"
        phpmyadmin_running=false
        phpmyadmin_config_ok=false
    fi

    echo ""

    # 12.2 - Variables de entorno
    if [ "$phpmyadmin_running" = true ]; then
        info "Verificando variables de entorno..."
        echo ""

        pma_host=$(docker compose exec -T phpmyadmin env 2>/dev/null | grep "^PMA_HOST=" | cut -d'=' -f2 || echo "")
        pma_port=$(docker compose exec -T phpmyadmin env 2>/dev/null | grep "^PMA_PORT=" | cut -d'=' -f2 || echo "")
        upload_limit=$(docker compose exec -T phpmyadmin env 2>/dev/null | grep "^UPLOAD_LIMIT=" | cut -d'=' -f2 || echo "")

        if [ "$pma_host" = "mysql" ]; then
            log "PMA_HOST: ${GREEN}mysql ✓${NC}"
        else
            error "PMA_HOST incorrecto: ${RED}$pma_host${NC} (esperado: mysql)"
            phpmyadmin_config_ok=false
        fi

        if [ "$pma_port" = "3306" ]; then
            log "PMA_PORT: ${GREEN}3306 ✓${NC}"
        else
            warning "PMA_PORT: ${YELLOW}$pma_port${NC} (esperado: 3306)"
        fi

        if [ -n "$upload_limit" ]; then
            log "UPLOAD_LIMIT: ${GREEN}$upload_limit ✓${NC}"
        else
            info "UPLOAD_LIMIT: no configurado (usando default)"
        fi

        echo ""
    fi

    # 12.3 - Configuración en Nginx
    info "Verificando configuración en nginx..."
    echo ""

    phpmyadmin_in_nginx=0
    for DOMAIN in "${DOMAINS[@]}"; do
        CONFIG_FILE="nginx/conf.d/${DOMAIN}.conf"
        if [ -f "$CONFIG_FILE" ]; then
            if grep -q "location.*phpmyadmin" "$CONFIG_FILE"; then
                log "  $DOMAIN: ${GREEN}✓ phpMyAdmin configurado${NC}"
                phpmyadmin_in_nginx=$((phpmyadmin_in_nginx + 1))

                # Verificar proxy_pass
                proxy_pass=$(grep -A 5 "location.*phpmyadmin" "$CONFIG_FILE" | grep "proxy_pass" | head -1 | sed 's/.*proxy_pass\s*\(.*\);/\1/' | xargs)
                if [ "$proxy_pass" = "http://phpmyadmin:80" ]; then
                    log "    proxy_pass correcto: ${GREEN}✓${NC}"
                else
                    error "    proxy_pass incorrecto: ${RED}$proxy_pass${NC}"
                    phpmyadmin_config_ok=false
                fi

                # Verificar autenticación básica
                if grep -A 5 "location.*phpmyadmin" "$CONFIG_FILE" | grep -q "auth_basic"; then
                    log "    Autenticación HTTP básica: ${GREEN}✓ configurada${NC}"

                    # Verificar archivo .htpasswd
                    if [ -f "nginx/auth/.htpasswd" ]; then
                        log "    Archivo .htpasswd: ${GREEN}✓ existe${NC}"
                        user_count=$(wc -l < nginx/auth/.htpasswd)
                        info "    Usuarios configurados: $user_count"
                    else
                        error "    Archivo .htpasswd: ${RED}✗ no existe${NC}"
                        phpmyadmin_config_ok=false
                    fi
                else
                    warning "    Autenticación HTTP básica: ${YELLOW}✗ no configurada${NC}"
                    warning "    Se recomienda configurar autenticación para seguridad"
                fi
            else
                warning "  $DOMAIN: ${YELLOW}✗ phpMyAdmin NO configurado${NC}"
            fi
        fi
    done

    if [ "$phpmyadmin_in_nginx" -eq 0 ]; then
        error "phpMyAdmin NO está configurado en ningún virtual host"
        phpmyadmin_config_ok=false
    else
        log "phpMyAdmin configurado en $phpmyadmin_in_nginx/${#DOMAINS[@]} dominios"
    fi

    echo ""

    # 12.4 - Conexión a MySQL
    if [ "$phpmyadmin_running" = true ]; then
        info "Verificando conectividad a MySQL..."
        echo ""

        # Probar ping a MySQL
        if docker compose exec -T phpmyadmin sh -c "ping -c 1 mysql >/dev/null 2>&1"; then
            log "Ping a MySQL: ${GREEN}✓ OK${NC}"
        else
            error "Ping a MySQL: ${RED}✗ FALLO${NC}"
            phpmyadmin_config_ok=false
        fi

        # Probar puerto 3306
        if docker compose exec -T phpmyadmin sh -c "nc -zv mysql 3306 2>&1" | grep -q "succeeded"; then
            log "Puerto 3306 accesible: ${GREEN}✓ OK${NC}"
        elif docker compose exec -T phpmyadmin sh -c "timeout 2 bash -c '</dev/tcp/mysql/3306' 2>/dev/null"; then
            log "Puerto 3306 accesible: ${GREEN}✓ OK${NC}"
        else
            error "Puerto 3306 NO accesible: ${RED}✗ FALLO${NC}"
            phpmyadmin_config_ok=false
        fi

        echo ""
    fi

    # 12.5 - Accesibilidad web
    if [ "$phpmyadmin_running" = true ] && [ "$nginx_running" = true ]; then
        info "Verificando accesibilidad web..."
        echo ""

        for DOMAIN in "${DOMAINS[@]}"; do
            CONFIG_FILE="nginx/conf.d/${DOMAIN}.conf"
            if [ -f "$CONFIG_FILE" ] && grep -q "location.*phpmyadmin" "$CONFIG_FILE"; then

                # Probar acceso HTTP
                response=$(docker compose exec -T nginx sh -c "curl -s -o /dev/null -w '%{http_code}' http://localhost/phpmyadmin/ 2>/dev/null" || echo "000")

                if [ "$response" = "401" ]; then
                    log "  http://$DOMAIN/phpmyadmin/ → ${GREEN}401${NC} (requiere autenticación) ${GREEN}✓${NC}"
                elif [ "$response" = "200" ]; then
                    log "  http://$DOMAIN/phpmyadmin/ → ${GREEN}200${NC} (accesible) ${GREEN}✓${NC}"
                elif [ "$response" = "302" ] || [ "$response" = "301" ]; then
                    log "  http://$DOMAIN/phpmyadmin/ → ${GREEN}$response${NC} (redirección) ${GREEN}✓${NC}"
                else
                    warning "  http://$DOMAIN/phpmyadmin/ → ${YELLOW}$response${NC}"
                    phpmyadmin_accessible=false
                fi
            fi
        done

        echo ""
    fi

    # 12.6 - Obtener credenciales
    if [ -f "nginx/auth/.htpasswd" ]; then
        info "Credenciales de acceso:"
        echo ""

        if grep -q "PHPMYADMIN_AUTH_USER=" .env 2>/dev/null; then
            pma_user=$(grep "PHPMYADMIN_AUTH_USER=" .env | cut -d'=' -f2)
            info "  Usuario HTTP: $pma_user"
            info "  Contraseña HTTP: (en .env - PHPMYADMIN_AUTH_PASSWORD)"
        fi

        info "  Usuario MySQL: root o wpuser"
        info "  Contraseña MySQL: (en .env - MYSQL_ROOT_PASSWORD o DB_PASSWORD)"
        echo ""
    fi

    # 12.7 - Recomendaciones de seguridad
    info "Recomendaciones de seguridad:"
    echo ""

    # Verificar que NO está expuesto directamente
    pma_ports=$(docker compose ps phpmyadmin --format json 2>/dev/null | grep -o '"PublishedPort":[0-9]*' | cut -d':' -f2 || echo "")
    if [ -z "$pma_ports" ]; then
        log "  ${GREEN}✓${NC} phpMyAdmin NO expuesto en puerto externo (solo proxy)"
    else
        error "  ${RED}✗${NC} phpMyAdmin EXPUESTO en puerto(s): $pma_ports"
        warning "  Se recomienda acceso solo vía proxy reverso"
    fi

    # Verificar autenticación
    if [ -f "nginx/auth/.htpasswd" ]; then
        log "  ${GREEN}✓${NC} Autenticación HTTP básica configurada"

        # Verificar longitud de contraseña
        if grep -q "PHPMYADMIN_AUTH_PASSWORD=" .env 2>/dev/null; then
            pma_pass=$(grep "PHPMYADMIN_AUTH_PASSWORD=" .env | cut -d'=' -f2)
            pass_length=${#pma_pass}
            if [ "$pass_length" -ge 16 ]; then
                log "  ${GREEN}✓${NC} Contraseña fuerte (≥16 caracteres)"
            else
                warning "  ${YELLOW}⚠${NC} Contraseña débil (<16 caracteres)"
                warning "  Se recomienda usar contraseña ≥16 caracteres"
            fi
        fi
    else
        warning "  ${YELLOW}⚠${NC} Autenticación HTTP NO configurada"
    fi

    # Verificar SSL
    ssl_configured=false
    for DOMAIN in "${DOMAINS[@]}"; do
        CONFIG_FILE="nginx/conf.d/${DOMAIN}.conf"
        if [ -f "$CONFIG_FILE" ]; then
            https_active=$(grep -c "^[[:space:]]*listen 443" "$CONFIG_FILE" 2>/dev/null || echo "0")
            if [ "$https_active" -gt 0 ]; then
                ssl_configured=true
                break
            fi
        fi
    done

    if [ "$ssl_configured" = true ]; then
        log "  ${GREEN}✓${NC} SSL/HTTPS configurado"
    else
        warning "  ${YELLOW}⚠${NC} SSL/HTTPS NO configurado"
        warning "  Ejecuta: ./scripts/setup-ssl.sh para configurar HTTPS"
    fi

    echo ""

fi

################################################################################
# 13. RESUMEN FINAL
################################################################################

title "13. RESUMEN DEL DIAGNÓSTICO"

echo -e "${CYAN}Estado General del Sistema:${NC}"
echo ""

# MySQL
echo -e "${MAGENTA}MySQL y Bases de Datos:${NC}"
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

# Nginx
echo -e "${MAGENTA}Nginx:${NC}"
if [ "$nginx_running" = true ]; then
    log "Contenedor nginx está corriendo"
else
    error "Contenedor nginx NO está corriendo"
fi

if [ "$nginx_config_valid" = true ]; then
    log "Configuración de nginx es válida"
else
    error "Configuración de nginx tiene errores"
fi

log "Virtual hosts configurados: $vhost_count/${#DOMAINS[@]}"

if [ "$all_vhosts_ok" = true ]; then
    log "Todos los virtual hosts están correctos"
else
    error "Hay problemas en algunos virtual hosts"
fi

# Verificar si hay SSL activo
ssl_count=0
for DOMAIN in "${DOMAINS[@]}"; do
    CONFIG_FILE="nginx/conf.d/${DOMAIN}.conf"
    if [ -f "$CONFIG_FILE" ]; then
        https_active=$(grep -c "^[[:space:]]*listen 443" "$CONFIG_FILE" 2>/dev/null || echo "0")
        if [ "$https_active" -gt 0 ]; then
            ssl_count=$((ssl_count + 1))
        fi
    fi
done

if [ "$ssl_count" -gt 0 ]; then
    log "SSL/HTTPS activo en $ssl_count/${#DOMAINS[@]} sitios"
else
    warning "SSL/HTTPS no configurado (ejecuta: ./scripts/setup-ssl.sh)"
fi

echo ""

# phpMyAdmin
if [ "$phpmyadmin_enabled" = true ]; then
    echo -e "${MAGENTA}phpMyAdmin:${NC}"
    if [ "$phpmyadmin_running" = true ]; then
        log "Contenedor phpmyadmin está corriendo"
    else
        error "Contenedor phpmyadmin NO está corriendo"
    fi

    if [ "$phpmyadmin_config_ok" = true ]; then
        log "Configuración de phpMyAdmin es correcta"
    else
        error "Hay problemas en la configuración de phpMyAdmin"
    fi

    if [ "$phpmyadmin_accessible" = true ]; then
        log "phpMyAdmin es accesible vía web"
    else
        warning "phpMyAdmin puede tener problemas de accesibilidad"
    fi

    log "phpMyAdmin configurado en $phpmyadmin_in_nginx/${#DOMAINS[@]} dominios"

    echo ""
fi

echo ""

# Veredicto final
all_ok=true
if [ "$all_dbs_ok" != true ] || [ "$all_connections_ok" != true ] || [ "$all_configs_ok" != true ] || [ "$nginx_running" != true ] || [ "$nginx_config_valid" != true ] || [ "$all_vhosts_ok" != true ]; then
    all_ok=false
fi

if [ "$phpmyadmin_enabled" = true ] && ([ "$phpmyadmin_running" != true ] || [ "$phpmyadmin_config_ok" != true ]); then
    all_ok=false
fi

if [ "$all_ok" = true ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                            ║${NC}"
    echo -e "${GREEN}║              ✓ TODOS LOS TESTS PASARON ✓                  ║${NC}"
    echo -e "${GREEN}║                                                            ║${NC}"
    echo -e "${GREEN}║     El sistema está configurado correctamente y           ║${NC}"
    echo -e "${GREEN}║     funcionando sin problemas.                             ║${NC}"
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
info "Comandos útiles:"
echo "  - Ver logs de MySQL: docker compose logs mysql"
echo "  - Ver logs de PHP: docker compose logs php"
echo "  - Ver logs de Nginx: docker compose logs nginx"
if [ "$phpmyadmin_enabled" = true ]; then
    echo "  - Ver logs de phpMyAdmin: docker compose logs phpmyadmin"
fi
echo "  - Reiniciar servicios: docker compose restart"
echo "  - Validar nginx: docker compose exec nginx nginx -t"
echo "  - Recargar nginx: docker compose exec nginx nginx -s reload"
echo ""

if [ "$phpmyadmin_enabled" = true ] && [ "$phpmyadmin_running" = true ]; then
    info "Acceso a phpMyAdmin:"
    for DOMAIN in "${DOMAINS[@]}"; do
        echo "  - http://$DOMAIN/phpmyadmin/"
        if [ "$ssl_count" -gt 0 ]; then
            echo "  - https://$DOMAIN/phpmyadmin/"
        fi
    done
    echo ""
fi