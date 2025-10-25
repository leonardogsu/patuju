#!/bin/bash

################################################################################
# Script para generar todas las configuraciones del proyecto
# VERSIÓN ACTUALIZADA - Sin comentarios descriptivos en bloque HTTPS
################################################################################

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Cargar variables de entorno
if [ ! -f .env ]; then
    echo -e "${RED}Error: Archivo .env no encontrado${NC}"
    exit 1
fi

source .env

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

################################################################################
# 0. GENERAR CREDENCIALES PARA PHPMYADMIN (SI ESTÁ HABILITADO)
################################################################################

PHPMYADMIN_ENABLED=false
if grep -q "INSTALL_PHPMYADMIN=true" .env 2>/dev/null; then
    PHPMYADMIN_ENABLED=true

    log "Generando credenciales para phpMyAdmin..."

    # Generar contraseña si no existe
    if ! grep -q "^PHPMYADMIN_AUTH_USER=" .env 2>/dev/null; then
        PHPMYADMIN_USER="phpmyadmin"
        PHPMYADMIN_PASSWORD=$(pwgen -s 16 1)

        # Añadir al .env
        echo "" >> .env
        echo "# phpMyAdmin Authentication" >> .env
        echo "PHPMYADMIN_AUTH_USER=$PHPMYADMIN_USER" >> .env
        echo "PHPMYADMIN_AUTH_PASSWORD=$PHPMYADMIN_PASSWORD" >> .env

        info "  Usuario: $PHPMYADMIN_USER"
        info "  Contraseña: $PHPMYADMIN_PASSWORD"
    else
        # Cargar credenciales existentes
        PHPMYADMIN_USER=$(grep "^PHPMYADMIN_AUTH_USER=" .env | cut -d'=' -f2)
        PHPMYADMIN_PASSWORD=$(grep "^PHPMYADMIN_AUTH_PASSWORD=" .env | cut -d'=' -f2)
        info "  Usando credenciales existentes para: $PHPMYADMIN_USER"
    fi

    # Crear directorio para nginx auth
    mkdir -p nginx/auth

    # Generar archivo .htpasswd
    log "Generando archivo .htpasswd..."

    # Verificar si htpasswd está disponible
    if ! command -v htpasswd &> /dev/null; then
        warning "htpasswd no encontrado, instalando apache2-utils..."
        apt-get update -qq
        apt-get install -y -qq apache2-utils
    fi

    # Crear .htpasswd
    htpasswd -bc nginx/auth/.htpasswd "$PHPMYADMIN_USER" "$PHPMYADMIN_PASSWORD"
    chmod 644 nginx/auth/.htpasswd

    log "✓ Credenciales de phpMyAdmin configuradas"
fi

# Añadir PMA_ABSOLUTE_URI al .env si no existe
    if ! grep -q "^PMA_ABSOLUTE_URI=" .env 2>/dev/null; then
        # Obtener el primer dominio
        FIRST_DOMAIN=$(grep "^DOMAIN_1=" .env | cut -d'=' -f2)
        if [ -n "$FIRST_DOMAIN" ]; then
            echo "" >> .env
            echo "# phpMyAdmin Configuration" >> .env
            echo "PMA_ABSOLUTE_URI=https://$FIRST_DOMAIN/phpmyadmin/" >> .env
            log "  PMA_ABSOLUTE_URI añadido al .env"
        fi
    fi

    log "✓ Credenciales de phpMyAdmin configuradas"

################################################################################
# 1. GENERAR DOCKER-COMPOSE.YML
################################################################################

log "Generando docker-compose.yml..."

cat > docker-compose.yml << 'DOCKERCOMPOSE'
services:
  nginx:
    image: nginx:alpine
    container_name: nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./www:/var/www/html
      - ./certbot/conf:/etc/letsencrypt:ro
      - ./certbot/www:/var/www/certbot:ro
      - ./logs/nginx:/var/log/nginx
    depends_on:
      - php
    networks:
      - wordpress-network
    restart: unless-stopped

  php:
    image: wordpress:php8.2-fpm-alpine
    container_name: php
    volumes:
      - ./www:/var/www/html
      - ./php/php.ini:/usr/local/etc/php/conf.d/custom.ini:ro
      - ./php/www.conf:/usr/local/etc/php-fpm.d/www.conf:ro
    environment:
      WORDPRESS_DB_HOST: mysql
      WORDPRESS_DB_USER: wpuser
      WORDPRESS_DB_PASSWORD: ${DB_PASSWORD}
    networks:
      - wordpress-network
    restart: unless-stopped
    depends_on:
      mysql:
        condition: service_healthy

  mysql:
    image: mysql:8.0
    container_name: mysql
    command: --default-authentication-plugin=mysql_native_password
    volumes:
      - ./mysql/data:/var/lib/mysql
      - ./mysql/init:/docker-entrypoint-initdb.d:ro
      - ./mysql/my.cnf:/etc/mysql/conf.d/my.cnf:ro
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_USER: wpuser
      MYSQL_PASSWORD: ${DB_PASSWORD}
    networks:
      - wordpress-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p${MYSQL_ROOT_PASSWORD}"]
      interval: 5s
      timeout: 3s
      retries: 30
      start_period: 30s

  certbot:
    image: certbot/certbot:latest
    container_name: certbot
    volumes:
      - ./certbot/conf:/etc/letsencrypt
      - ./certbot/www:/var/www/certbot
    entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait $${!}; done;'"
    networks:
      - wordpress-network
DOCKERCOMPOSE

# Añadir volumen de autenticación si phpMyAdmin está habilitado
if [ "$PHPMYADMIN_ENABLED" = true ]; then
    # Añadir el volumen de auth a nginx
    sed -i '/.*logs\/nginx:\/var\/log\/nginx/a\      - ./nginx/auth:/etc/nginx/auth:ro' docker-compose.yml
fi

# Añadir phpMyAdmin si está habilitado (SIN exponer puerto externo)
if [ "$PHPMYADMIN_ENABLED" = true ]; then
    cat >> docker-compose.yml << 'PHPMYADMIN'

  phpmyadmin:
    image: phpmyadmin:latest
    container_name: phpmyadmin
    environment:
      PMA_HOST: mysql
      PMA_PORT: 3306
      PMA_ABSOLUTE_URI: ${PMA_ABSOLUTE_URI}
      UPLOAD_LIMIT: 100M
    networks:
      - wordpress-network
    restart: unless-stopped
    depends_on:
      - mysql
PHPMYADMIN
fi

# Añadir FTP si está habilitado
if grep -q "INSTALL_FTP=true" .env 2>/dev/null; then
    cat >> docker-compose.yml << 'FTP'

  ftp:
    image: delfer/alpine-ftp-server
    container_name: ftp
    ports:
      - "21:21"
      - "21000-21010:21000-21010"
    volumes:
      - ./www:/home/ftpuser/www
    environment:
      USERS: "ftpuser|${FTP_PASSWORD}|/home/ftpuser/www"
      ADDRESS: ${SERVER_IP}
    networks:
      - wordpress-network
    restart: unless-stopped
FTP
fi

cat >> docker-compose.yml << 'DOCKEREND'

networks:
  wordpress-network:
    driver: bridge

volumes:
  mysql-data:
DOCKEREND

log "docker-compose.yml generado ✅"


################################################################################
# 2. GENERAR CONFIGURACIÓN DE NGINX
################################################################################

log "Generando configuración de Nginx..."

cat > nginx/nginx.conf << 'NGINXCONF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 2048;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 100M;

    # Gzip
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript
               application/json application/javascript application/xml+rss
               application/rss+xml font/truetype font/opentype
               application/vnd.ms-fontobject image/svg+xml;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Incluir configuraciones de sitios
    include /etc/nginx/conf.d/*.conf;
}
NGINXCONF

log "nginx.conf generado"

################################################################################
# 3. GENERAR VIRTUAL HOSTS DE NGINX
################################################################################

log "Generando configuraciones de virtual hosts..."

# Obtener lista de dominios
DOMAINS=($(grep "^DOMAIN_" .env | cut -d'=' -f2))

for i in "${!DOMAINS[@]}"; do
    DOMAIN="${DOMAINS[$i]}"
    SITE_NUM=$((i + 1))

    log "  Generando configuración para $DOMAIN (sitio $SITE_NUM)"

    cat > "nginx/conf.d/${DOMAIN}.conf" << VHOSTEOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN www.$DOMAIN;

    location ^~ /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # return 301 https://\$server_name\$request_uri;

    root /var/www/html/sitio$SITE_NUM;
    index index.php index.html index.htm;

VHOSTEOF

    # Añadir configuración de phpMyAdmin si está habilitado
    if [ "$PHPMYADMIN_ENABLED" = true ]; then
        cat >> "nginx/conf.d/${DOMAIN}.conf" << 'PHPMYADMINLOC'
    location ^~ /phpmyadmin/ {
            auth_basic "Acceso Restringido - phpMyAdmin";
            auth_basic_user_file /etc/nginx/auth/.htpasswd;

            proxy_pass http://phpmyadmin:80/;

            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_set_header X-Forwarded-Host \$host;
            proxy_set_header X-Forwarded-Port \$server_port;

            proxy_redirect ~^/(.*)\$ /phpmyadmin/\$1;

            proxy_read_timeout 300;
            proxy_connect_timeout 300;
            proxy_send_timeout 300;

            proxy_buffering off;
        }

    location = /phpmyadmin {
        return 301 /phpmyadmin/;
    }

PHPMYADMINLOC
    fi

    cat >> "nginx/conf.d/${DOMAIN}.conf" << 'VHOSTEOF2'
    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass php:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;
        fastcgi_read_timeout 300;
    }

    location ~ /\.ht {
        deny all;
    }

    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }

    location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires max;
        log_not_found off;
    }
}

# server {
#     listen 443 ssl;
#     listen [::]:443 ssl;
#     http2 on;
#     server_name $DOMAIN www.$DOMAIN;
#
#     ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
#     ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
#     ssl_protocols TLSv1.2 TLSv1.3;
#     ssl_ciphers HIGH:!aNULL:!MD5;
#     ssl_prefer_server_ciphers on;
#
#     root /var/www/html/sitio$SITE_NUM;
#     index index.php index.html index.htm;
#
VHOSTEOF2

    # Añadir configuración de phpMyAdmin para HTTPS si está habilitado
    if [ "$PHPMYADMIN_ENABLED" = true ]; then
        cat >> "nginx/conf.d/${DOMAIN}.conf" << 'PHPMYADMINLOCHTTPS'
#     location ^~ /phpmyadmin/ {
#         auth_basic "Acceso Restringido - phpMyAdmin";
#         auth_basic_user_file /etc/nginx/auth/.htpasswd;
#
#         rewrite ^/phpmyadmin/(.*) /$1 break;
#         proxy_pass http://phpmyadmin:80;
#         proxy_set_header Host $host;
#         proxy_set_header X-Real-IP $remote_addr;
#         proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
#         proxy_set_header X-Forwarded-Proto $scheme;
#         proxy_redirect off;
#
#         proxy_read_timeout 300;
#         proxy_connect_timeout 300;
#         proxy_send_timeout 300;
#     }
#
#     location = /phpmyadmin {
#         return 301 /phpmyadmin/;
#     }
#
PHPMYADMINLOCHTTPS
    fi

    cat >> "nginx/conf.d/${DOMAIN}.conf" << 'VHOSTEOF3'
#     location / {
#         try_files $uri $uri/ /index.php?$args;
#     }
#
#     location ~ \.php$ {
#         fastcgi_split_path_info ^(.+\.php)(/.+)$;
#         fastcgi_pass php:9000;
#         fastcgi_index index.php;
#         include fastcgi_params;
#         fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
#         fastcgi_param PATH_INFO $fastcgi_path_info;
#         fastcgi_read_timeout 300;
#     }
#
#     location ~ /\.ht {
#         deny all;
#     }
#
#     location = /favicon.ico {
#         log_not_found off;
#         access_log off;
#     }
#
#     location = /robots.txt {
#         allow all;
#         log_not_found off;
#         access_log off;
#     }
#
#     location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
#         expires max;
#         log_not_found off;
#     }
# }
VHOSTEOF3
done

log "Virtual hosts generados: ${#DOMAINS[@]} sitios"

################################################################################
# 4. GENERAR CONFIGURACIONES PHP
################################################################################

log "Generando configuraciones de PHP..."

cat > php/php.ini << 'PHPINI'
[PHP]
memory_limit = 256M
upload_max_filesize = 100M
post_max_size = 100M
max_execution_time = 300
max_input_time = 300
date.timezone = Europe/Madrid

[opcache]
opcache.enable=1
opcache.memory_consumption=128
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=4000
opcache.revalidate_freq=60
opcache.fast_shutdown=1
PHPINI

cat > php/www.conf << 'WWWCONF'
[www]
user = www-data
group = www-data
listen = 9000
listen.owner = www-data
listen.group = www-data
pm = dynamic
pm.max_children = 50
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 35
pm.max_requests = 500
WWWCONF

log "Configuraciones de PHP generadas"

################################################################################
# 5. GENERAR CONFIGURACIÓN MYSQL
################################################################################

log "Generando configuraciones de MySQL..."

cat > mysql/my.cnf << 'MYCNF'
[mysqld]
max_connections = 200
max_allowed_packet = 64M
innodb_buffer_pool_size = 512M
innodb_redo_log_capacity = 134217728
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT

[mysqldump]
quick
quote-names
max_allowed_packet = 64M
MYCNF

# Script de inicialización de bases de datos
log "Generando script de inicialización de bases de datos..."

cat > mysql/init/01-init-databases.sql << 'INITSQL'
-- Script de inicialización de bases de datos WordPress
INITSQL

DOMAINS=($(grep "^DOMAIN_" .env | cut -d'=' -f2))

for i in "${!DOMAINS[@]}"; do
    SITE_NUM=$((i + 1))
    echo "CREATE DATABASE IF NOT EXISTS wp_sitio$SITE_NUM CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" >> mysql/init/01-init-databases.sql
done

echo "" >> mysql/init/01-init-databases.sql

for i in "${!DOMAINS[@]}"; do
    SITE_NUM=$((i + 1))
    echo "GRANT ALL PRIVILEGES ON wp_sitio$SITE_NUM.* TO 'wpuser'@'%';" >> mysql/init/01-init-databases.sql
done

echo "" >> mysql/init/01-init-databases.sql
echo "FLUSH PRIVILEGES;" >> mysql/init/01-init-databases.sql

log "Configuraciones de MySQL generadas"

################################################################################
# 6. GENERAR .GITIGNORE
################################################################################

log "Generando .gitignore..."

cat > .gitignore << 'GITIGNORE'
# Variables de entorno
.env

# WordPress
www/*/wp-config.php
www/*/wp-content/uploads/
www/*/wp-content/cache/
www/*/wp-content/upgrade/
www/*/wp-content/backups/

# MySQL
mysql/data/

# Logs
logs/
*.log

# Backups
backups/

# Certificados SSL
certbot/conf/
certbot/www/

# Nginx Auth
nginx/auth/.htpasswd

# Archivos temporales
*.swp
*.swo
*~
.DS_Store
Thumbs.db

# IDE
.vscode/
.idea/
*.sublime-project
*.sublime-workspace

# Docker
.docker/
GITIGNORE

log "✓ Todas las configuraciones han sido generadas exitosamente"

# Mostrar información de phpMyAdmin si está habilitado
if [ "$PHPMYADMIN_ENABLED" = true ]; then
    echo ""
    info "═══════════════════════════════════════════════════════════"
    info "PHPMYADMIN CONFIGURADO"
    info "═══════════════════════════════════════════════════════════"
    echo "  Acceso a través de cualquier dominio:"
    for DOMAIN in "${DOMAINS[@]}"; do
        echo "    http://$DOMAIN/phpmyadmin/"
    done
    echo ""
    echo "  Credenciales de autenticación HTTP:"
    echo "    Usuario: $PHPMYADMIN_USER"
    echo "    Contraseña: $PHPMYADMIN_PASSWORD"
    echo ""
    echo "  Luego ingresa las credenciales de MySQL:"
    echo "    Servidor: mysql"
    echo "    Usuario: wpuser o root"
    echo "    Contraseña: (la del .env)"
    info "═══════════════════════════════════════════════════════════"
fi

echo ""
log "Próximo paso: ./scripts/setup.sh para iniciar los contenedores"