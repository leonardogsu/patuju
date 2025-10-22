#!/bin/bash
# Script para generar configuraciones de Nginx para los sitios restantes

# Uso: ./generate-site-config.sh NUMERO DOMINIO
# Ejemplo: ./generate-site-config.sh 3 sitio3.com

if [ "$#" -ne 2 ]; then
    echo "Uso: $0 NUMERO DOMINIO"
    echo "Ejemplo: $0 3 sitio3.com"
    exit 1
fi

NUMERO=$1
DOMINIO=$2
ARCHIVO="nginx/conf.d/sitio${NUMERO}.conf"

cat > $ARCHIVO << EOF
# Sitio $NUMERO - $DOMINIO (1K visitas/día)
server {
    listen 80;
    listen [::]:80;
    server_name $DOMINIO www.$DOMINIO;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMINIO www.$DOMINIO;

    root /var/www/html/sitio${NUMERO};
    index index.php index.html;

    ssl_certificate /etc/letsencrypt/live/$DOMINIO/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMINIO/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256';
    ssl_prefer_server_ciphers off;

    access_log /var/log/nginx/sitio${NUMERO}-access.log;
    error_log /var/log/nginx/sitio${NUMERO}-error.log;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        try_files \$uri =404;
        fastcgi_pass php:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    location = /wp-login.php {
        limit_req zone=wplogin burst=2 nodelay;
        fastcgi_pass php:9000;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    location ~ /\.ht {
        deny all;
    }

    location = /xmlrpc.php {
        deny all;
    }

    location ~* wp-config.php {
        deny all;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
}
EOF

echo "✓ Configuración creada: $ARCHIVO"
echo ""
echo "Próximos pasos:"
echo "1. Revisa el archivo: cat $ARCHIVO"
echo "2. Reinicia Nginx: docker-compose restart nginx"
echo "3. Obtén SSL: ./scripts/get-ssl.sh $DOMINIO"
