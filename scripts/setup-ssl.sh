#!/bin/bash

################################################################################
# Script de gestión de certificados SSL con Let's Encrypt
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
log "CONFIGURACIÓN DE CERTIFICADOS SSL"
log "═══════════════════════════════════════════════════"
echo ""

# Verificar que los contenedores estén corriendo
if ! docker compose ps | grep -q "Up"; then
    error "Los contenedores no están corriendo. Ejecuta primero: ./scripts/setup.sh"
fi

# Obtener dominios
DOMAINS=($(grep "^DOMAIN_" .env | cut -d'=' -f2))

# Solicitar email
read -p "Ingresa tu email para Let's Encrypt: " EMAIL

if [ -z "$EMAIL" ]; then
    error "Email es requerido"
fi

log "Email configurado: $EMAIL"
echo ""

################################################################################
# OBTENER CERTIFICADOS
################################################################################

log "Obteniendo certificados SSL..."
echo ""

for DOMAIN in "${DOMAINS[@]}"; do
    log "Procesando: $DOMAIN"
    
    # Verificar si ya existe el certificado
    if [ -d "certbot/conf/live/$DOMAIN" ]; then
        warning "  Certificado ya existe para $DOMAIN"
        read -p "  ¿Renovar certificado? (s/n): " renew
        if [[ ! $renew =~ ^[Ss]$ ]]; then
            log "  Omitiendo $DOMAIN"
            continue
        fi
    fi
    
    # Obtener certificado
    log "  Obteniendo certificado para $DOMAIN..."
    
    docker compose run --rm certbot certonly \
        --webroot \
        --webroot-path=/var/www/certbot \
        --email "$EMAIL" \
        --agree-tos \
        --no-eff-email \
        --force-renewal \
        -d "$DOMAIN" \
        -d "www.$DOMAIN" \
        || warning "  Error al obtener certificado para $DOMAIN"
    
    if [ -d "certbot/conf/live/$DOMAIN" ]; then
        log "  ✓ Certificado obtenido para $DOMAIN"
    else
        warning "  ✗ No se pudo obtener certificado para $DOMAIN"
        continue
    fi
done

echo ""

################################################################################
# ACTIVAR HTTPS EN NGINX
################################################################################

log "Activando HTTPS en configuraciones de Nginx..."

for DOMAIN in "${DOMAINS[@]}"; do
    if [ ! -d "certbot/conf/live/$DOMAIN" ]; then
        warning "  No hay certificado para $DOMAIN, omitiendo..."
        continue
    fi
    
    CONFIG_FILE="nginx/conf.d/${DOMAIN}.conf"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        warning "  Archivo de configuración no encontrado: $CONFIG_FILE"
        continue
    fi
    
    log "  Actualizando configuración para $DOMAIN..."
    
    # Descomentar redirección HTTPS
    sed -i 's/# return 301 https/return 301 https/g' "$CONFIG_FILE"
    
    # Descomentar bloque HTTPS
    sed -i '/# server {/,/# }/s/^# //g' "$CONFIG_FILE"
    
    log "  ✓ Configuración actualizada para $DOMAIN"
done

################################################################################
# RECARGAR NGINX
################################################################################

log "Recargando Nginx..."
docker compose exec nginx nginx -s reload || error "Error al recargar Nginx"
log "✓ Nginx recargado"

################################################################################
# RESUMEN
################################################################################

echo ""
log "═══════════════════════════════════════════════════"
log "CONFIGURACIÓN SSL COMPLETADA"
log "═══════════════════════════════════════════════════"
echo ""

info "Certificados instalados:"
for DOMAIN in "${DOMAINS[@]}"; do
    if [ -d "certbot/conf/live/$DOMAIN" ]; then
        echo "  ✓ $DOMAIN"
        EXPIRY=$(docker compose run --rm certbot certificates | grep -A2 "$DOMAIN" | grep "Expiry Date" | awk '{print $3, $4}')
        echo "    Expira: $EXPIRY"
    else
        echo "  ✗ $DOMAIN (no instalado)"
    fi
done

echo ""
info "Tus sitios ahora están disponibles en HTTPS:"
for DOMAIN in "${DOMAINS[@]}"; do
    if [ -d "certbot/conf/live/$DOMAIN" ]; then
        echo "  https://$DOMAIN"
    fi
done

echo ""
info "Los certificados se renovarán automáticamente"
info "Para forzar renovación: docker compose run --rm certbot renew"
echo ""
