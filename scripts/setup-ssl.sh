#!/bin/bash

################################################################################
# Script de gestión de certificados SSL con Let's Encrypt
# Versión corregida con entrypoint apropiado para certbot
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

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
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

# Verificar si phpMyAdmin está habilitado
PHPMYADMIN_ENABLED=false
if grep -q "INSTALL_PHPMYADMIN=true" .env 2>/dev/null; then
    PHPMYADMIN_ENABLED=true
    info "phpMyAdmin detectado - se configurará SSL para él también"
fi

# Obtener dominios
DOMAINS=($(grep "^DOMAIN_" .env | cut -d'=' -f2))

if [ ${#DOMAINS[@]} -eq 0 ]; then
    error "No se encontraron dominios en .env"
fi

info "Dominios a procesar: ${DOMAINS[@]}"
echo ""

# Solicitar email
read -p "Ingresa tu email para Let's Encrypt: " EMAIL

if [ -z "$EMAIL" ]; then
    error "Email es requerido para Let's Encrypt"
fi

# Validar formato de email básico
if [[ ! "$EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    error "Formato de email inválido"
fi

log "Email configurado: $EMAIL"
echo ""

warning "IMPORTANTE: Antes de continuar, asegúrate de que:"
echo "  1. Los DNS de tus dominios apuntan a este servidor ($SERVER_IP)"
echo "  2. Los puertos 80 y 443 están abiertos en el firewall"
echo "  3. Los sitios WordPress responden correctamente en HTTP"
echo ""
read -p "¿Continuar con la obtención de certificados SSL? (s/n): " confirm
if [[ ! $confirm =~ ^[Ss]$ ]]; then
    error "Proceso cancelado por el usuario"
fi

echo ""

################################################################################
# OBTENER CERTIFICADOS
################################################################################

log "═══════════════════════════════════════════════════"
log "PASO 1: Obtención de certificados SSL"
log "═══════════════════════════════════════════════════"
echo ""

SUCCESSFUL_CERTS=()
FAILED_CERTS=()

for DOMAIN in "${DOMAINS[@]}"; do
    log "Procesando dominio: $DOMAIN"

    # Verificar si ya existe el certificado
    if [ -d "certbot/conf/live/$DOMAIN" ]; then
        warning "  Certificado ya existe para $DOMAIN"

        # Mostrar fecha de expiración
        EXPIRY=$(openssl x509 -enddate -noout -in "certbot/conf/live/$DOMAIN/cert.pem" 2>/dev/null | cut -d= -f2 || echo "Desconocida")
        info "  Expira: $EXPIRY"

        read -p "  ¿Renovar/Recrear certificado? (s/n): " renew
        if [[ ! $renew =~ ^[Ss]$ ]]; then
            log "  Omitiendo $DOMAIN (usando certificado existente)"
            SUCCESSFUL_CERTS+=("$DOMAIN")
            echo ""
            continue
        fi

        # Si el usuario quiere renovar, eliminar certificados existentes
        log "  Eliminando certificados existentes..."
        rm -rf "certbot/conf/live/$DOMAIN"
        rm -rf "certbot/conf/archive/$DOMAIN"
        rm -rf "certbot/conf/renewal/$DOMAIN.conf"
        success "  ✓ Certificados anteriores eliminados"
    fi

    # Probar conectividad HTTP primero
    log "  Verificando que $DOMAIN es accesible vía HTTP..."
    if curl -s -f -o /dev/null --max-time 5 "http://$DOMAIN" 2>/dev/null; then
        success "  ✓ Dominio accesible vía HTTP"
    else
        warning "  ⚠ No se pudo verificar acceso HTTP a $DOMAIN"
        warning "  Esto puede causar que la validación de Let's Encrypt falle"
        read -p "  ¿Continuar de todos modos? (s/n): " continue_anyway
        if [[ ! $continue_anyway =~ ^[Ss]$ ]]; then
            warning "  Omitiendo $DOMAIN"
            FAILED_CERTS+=("$DOMAIN")
            echo ""
            continue
        fi
    fi

    # Obtener certificado - IMPORTANTE: usar --entrypoint certbot
    log "  Solicitando certificado SSL para $DOMAIN y www.$DOMAIN..."
    echo "  (Esto puede tardar 1-2 minutos...)"

    if docker compose run --rm --entrypoint certbot certbot certonly \
        --webroot \
        --webroot-path=/var/www/certbot \
        --email "$EMAIL" \
        --agree-tos \
        --no-eff-email \
        --force-renewal \
        -d "$DOMAIN" \
        -d "www.$DOMAIN" 2>&1 | tee /tmp/certbot_${DOMAIN}.log; then

        # Verificar que el certificado se creó correctamente
        if [ -d "certbot/conf/live/$DOMAIN" ] && [ -f "certbot/conf/live/$DOMAIN/fullchain.pem" ]; then
            success "  ✓ Certificado obtenido exitosamente para $DOMAIN"
            SUCCESSFUL_CERTS+=("$DOMAIN")
        else
            warning "  ✗ El proceso terminó pero no se encontró el certificado"
            warning "  Verifica el log: /tmp/certbot_${DOMAIN}.log"
            FAILED_CERTS+=("$DOMAIN")
        fi
    else
        warning "  ✗ Error al obtener certificado para $DOMAIN"
        warning "  Causas comunes:"
        echo "    - DNS no apunta a $SERVER_IP"
        echo "    - Puerto 80 bloqueado"
        echo "    - Nginx no está funcionando correctamente"
        warning "  Revisa el log: /tmp/certbot_${DOMAIN}.log"
        FAILED_CERTS+=("$DOMAIN")
    fi

    echo ""
done

# Resumen de certificados obtenidos
echo ""
log "═══════════════════════════════════════════════════"
log "RESUMEN DE CERTIFICADOS"
log "═══════════════════════════════════════════════════"
echo ""

if [ ${#SUCCESSFUL_CERTS[@]} -gt 0 ]; then
    success "Certificados exitosos (${#SUCCESSFUL_CERTS[@]}):"
    for domain in "${SUCCESSFUL_CERTS[@]}"; do
        echo "  ✓ $domain"
    done
    echo ""
fi

if [ ${#FAILED_CERTS[@]} -gt 0 ]; then
    warning "Certificados fallidos (${#FAILED_CERTS[@]}):"
    for domain in "${FAILED_CERTS[@]}"; do
        echo "  ✗ $domain"
    done
    echo ""
    warning "Los dominios fallidos NO se configurarán con HTTPS"
    echo ""
fi

if [ ${#SUCCESSFUL_CERTS[@]} -eq 0 ]; then
    error "No se obtuvo ningún certificado. Verifica DNS y conectividad."
fi

################################################################################
# ACTIVAR HTTPS EN NGINX
################################################################################

log "═══════════════════════════════════════════════════"
log "PASO 2: Activación de HTTPS en Nginx"
log "═══════════════════════════════════════════════════"
echo ""

for DOMAIN in "${SUCCESSFUL_CERTS[@]}"; do
    CONFIG_FILE="nginx/conf.d/${DOMAIN}.conf"

    if [ ! -f "$CONFIG_FILE" ]; then
        warning "  Configuración no encontrada: $CONFIG_FILE"
        continue
    fi

    log "Actualizando configuración para $DOMAIN..."

    # Crear backup
    cp "$CONFIG_FILE" "${CONFIG_FILE}.backup-$(date +%Y%m%d-%H%M%S)"

    # Crear archivo temporal para la nueva configuración
    TEMP_FILE=$(mktemp)

    # Estado para saber si estamos dentro del bloque HTTPS comentado
    IN_HTTPS_BLOCK=false

    while IFS= read -r line; do
        # Detectar inicio del bloque HTTPS
        if [[ "$line" =~ ^#[[:space:]]*server[[:space:]]*\{[[:space:]]*$ ]] && ! $IN_HTTPS_BLOCK; then
            # Leer la siguiente línea para confirmar que es el bloque HTTPS
            next_line=""
            if IFS= read -r next_line; then
                if [[ "$next_line" =~ listen[[:space:]]+443[[:space:]]+ssl ]]; then
                    IN_HTTPS_BLOCK=true
                    # Descomentar la línea actual (server {)
                    echo "${line//#[[:space:]]/}" >> "$TEMP_FILE"
                    # Descomentar la siguiente línea (listen 443)
                    echo "${next_line//#[[:space:]]/}" >> "$TEMP_FILE"
                    continue
                else
                    # No es el bloque HTTPS, escribir ambas líneas sin modificar
                    echo "$line" >> "$TEMP_FILE"
                    echo "$next_line" >> "$TEMP_FILE"
                    continue
                fi
            fi
        fi

        # Si estamos dentro del bloque HTTPS, descomentar todas las líneas
        if $IN_HTTPS_BLOCK; then
            # Detectar fin del bloque
            if [[ "$line" =~ ^#[[:space:]]*\}[[:space:]]*$ ]]; then
                IN_HTTPS_BLOCK=false
                echo "}" >> "$TEMP_FILE"
                continue
            fi

            # Descomentar la línea (quitar # y espacios iniciales después del #)
            uncommented="${line//#[[:space:]]/}"
            # Si la línea queda vacía o solo con espacios después de descomentar, mantener estructura
            if [[ -n "$uncommented" ]]; then
                echo "$uncommented" >> "$TEMP_FILE"
            else
                echo "" >> "$TEMP_FILE"
            fi
        else
            # Fuera del bloque HTTPS, escribir la línea tal cual
            echo "$line" >> "$TEMP_FILE"
        fi
    done < "$CONFIG_FILE"

    # Reemplazar archivo original
    mv "$TEMP_FILE" "$CONFIG_FILE"

    success "  ✓ Bloque HTTPS activado para $DOMAIN"
done

echo ""

################################################################################
# ACTIVAR REDIRECCIÓN HTTP → HTTPS
################################################################################

log "═══════════════════════════════════════════════════"
log "PASO 3: Activación de redirección HTTP → HTTPS"
log "═══════════════════════════════════════════════════"
echo ""

warning "Esto redirigirá TODO el tráfico HTTP a HTTPS"
read -p "¿Activar redirección ahora? (s/n): " enable_redirect

if [[ $enable_redirect =~ ^[Ss]$ ]]; then
    for DOMAIN in "${SUCCESSFUL_CERTS[@]}"; do
        CONFIG_FILE="nginx/conf.d/${DOMAIN}.conf"

        log "  Activando redirección para $DOMAIN..."

        # Descomentar la línea de redirección en el bloque HTTP (puerto 80)
        sed -i 's/^[[:space:]]*#[[:space:]]*return 301 https/    return 301 https/g' "$CONFIG_FILE"

        success "  ✓ Redirección activada para $DOMAIN"
    done
    echo ""
    info "Redirección HTTP → HTTPS activada"
else
    echo ""
    info "Redirección NO activada. Para activarla manualmente:"
    echo "  Edita los archivos nginx/conf.d/*.conf"
    echo "  Descomenta la línea: # return 301 https://\$server_name\$request_uri;"
fi

echo ""

################################################################################
# VALIDAR Y RECARGAR NGINX
################################################################################

log "═══════════════════════════════════════════════════"
log "PASO 4: Validación y recarga de Nginx"
log "═══════════════════════════════════════════════════"
echo ""

log "Validando configuración de Nginx..."
if docker compose exec nginx nginx -t 2>&1 | grep -q "syntax is ok"; then
    success "✓ Configuración de Nginx válida"

    log "Recargando Nginx..."
    if docker compose exec nginx nginx -s reload; then
        success "✓ Nginx recargado exitosamente"
    else
        error "Error al recargar Nginx"
    fi
else
    error "La configuración de Nginx tiene errores. Revisa los archivos de configuración."
fi

################################################################################
# RESUMEN FINAL
################################################################################

echo ""
log "═══════════════════════════════════════════════════"
log "✓ CONFIGURACIÓN SSL COMPLETADA"
log "═══════════════════════════════════════════════════"
echo ""

success "Certificados SSL instalados y activos:"
for DOMAIN in "${SUCCESSFUL_CERTS[@]}"; do
    echo "  ✓ https://$DOMAIN"
    echo "  ✓ https://www.$DOMAIN"

    # Mostrar expiración
    if [ -f "certbot/conf/live/$DOMAIN/cert.pem" ]; then
        EXPIRY=$(openssl x509 -enddate -noout -in "certbot/conf/live/$DOMAIN/cert.pem" 2>/dev/null | cut -d= -f2)
        echo "     Expira: $EXPIRY"
    fi

    # Mostrar acceso a phpMyAdmin si está habilitado
    if [ "$PHPMYADMIN_ENABLED" = true ]; then
        echo "     phpMyAdmin: https://$DOMAIN/phpmyadmin/"
    fi
    echo ""
done

if [ ${#FAILED_CERTS[@]} -gt 0 ]; then
    echo ""
    warning "Dominios sin SSL (aún accesibles por HTTP):"
    for domain in "${FAILED_CERTS[@]}"; do
        echo "  → http://$domain"
    done
fi

echo ""
info "═══ INFORMACIÓN IMPORTANTE ═══"
echo ""
echo "  • Los certificados SSL se renovarán automáticamente cada 12 horas"
echo "  • Los certificados son válidos por 90 días"
echo "  • Let's Encrypt tiene límite de 5 certificados por dominio por semana"
echo ""
echo "  Comandos útiles:"
echo "    - Ver certificados: docker compose run --rm --entrypoint certbot certbot certificates"
echo "    - Renovar manualmente: docker compose run --rm --entrypoint certbot certbot renew"
echo "    - Ver logs de certbot: docker compose exec certbot cat /var/log/letsencrypt/letsencrypt.log"
echo "    - Ver logs de Nginx: docker compose logs nginx"
echo "    - Probar configuración: docker compose exec nginx nginx -t"
echo ""

if [ "$PHPMYADMIN_ENABLED" = true ]; then
    info "═══ ACCESO A PHPMYADMIN ═══"
    echo ""
    echo "  Ahora phpMyAdmin está disponible con SSL:"
    for DOMAIN in "${SUCCESSFUL_CERTS[@]}"; do
        echo "    https://$DOMAIN/phpmyadmin/"
    done
    echo ""
    echo "  Credenciales HTTP (primera capa):"
    PHPMYADMIN_USER=$(grep "^PHPMYADMIN_AUTH_USER=" .env | cut -d'=' -f2)
    echo "    Usuario: $PHPMYADMIN_USER"
    echo "    (Contraseña en .env)"
    echo ""
fi

success "¡Tus sitios ahora están protegidos con SSL/TLS!"
echo ""