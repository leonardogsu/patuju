#!/bin/bash
# Script para obtener certificados SSL con Let's Encrypt

set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

if [ "$#" -lt 1 ]; then
    echo -e "${RED}Uso: $0 dominio.com [email@ejemplo.com]${NC}"
    echo "Ejemplo: $0 sitio1.com admin@sitio1.com"
    exit 1
fi

DOMAIN=$1
EMAIL=${2:-"admin@$DOMAIN"}

echo "==================================="
echo "Obteniendo certificado SSL"
echo "==================================="
echo "Dominio: $DOMAIN"
echo "Email: $EMAIL"
echo ""

# Verificar que Nginx está corriendo
if ! docker ps | grep -q nginx-web; then
    echo -e "${RED}Error: Contenedor nginx-web no está corriendo${NC}"
    echo "Ejecuta: docker-compose up -d"
    exit 1
fi

echo -e "${YELLOW}1. Verificando configuración de Nginx...${NC}"

# Verificar que existe la configuración del dominio
CONF_FILE="nginx/conf.d/$(echo $DOMAIN | sed 's/www\.//').conf"
if [ ! -f "$CONF_FILE" ]; then
    echo -e "${RED}Error: No se encontró $CONF_FILE${NC}"
    echo "Crea la configuración de Nginx primero"
    exit 1
fi

echo -e "${GREEN}✓ Configuración encontrada${NC}"

echo ""
echo -e "${YELLOW}2. Obteniendo certificado...${NC}"

# Obtener certificado
docker-compose run --rm certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email $EMAIL \
    --agree-tos \
    --no-eff-email \
    -d $DOMAIN \
    -d www.$DOMAIN

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Certificado obtenido exitosamente${NC}"
    
    echo ""
    echo -e "${YELLOW}3. Reiniciando Nginx...${NC}"
    docker-compose restart nginx
    
    echo ""
    echo -e "${GREEN}==================================="
    echo "¡Certificado SSL instalado!"
    echo "===================================${NC}"
    echo ""
    echo "Tu sitio ahora está disponible en: https://$DOMAIN"
    echo ""
    echo "El certificado se renovará automáticamente."
    echo ""
else
    echo -e "${RED}Error al obtener el certificado${NC}"
    echo ""
    echo "Verifica que:"
    echo "1. El dominio $DOMAIN apunta a tu servidor"
    echo "2. Los puertos 80 y 443 están abiertos"
    echo "3. Nginx está corriendo correctamente"
    exit 1
fi
