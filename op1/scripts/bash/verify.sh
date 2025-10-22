#!/bin/bash
# Script de verificación antes del despliegue

set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

errors=0
warnings=0

echo "=========================================="
echo "Verificación Pre-Deploy"
echo "=========================================="
echo ""

# Verificar Docker
echo -n "Verificando Docker... "
if command -v docker &> /dev/null; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗ Docker no instalado${NC}"
    errors=$((errors + 1))
fi

# Verificar Docker Compose
echo -n "Verificando Docker Compose... "
if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗ Docker Compose no instalado${NC}"
    errors=$((errors + 1))
fi

# Verificar archivo .env
echo -n "Verificando archivo .env... "
if [ -f ".env" ]; then
    echo -e "${GREEN}✓${NC}"
    
    # Verificar que se cambiaron las contraseñas
    echo -n "  Verificando contraseñas personalizadas... "
    if grep -q "tu_password" .env; then
        echo -e "${RED}✗ Debes cambiar las contraseñas en .env${NC}"
        errors=$((errors + 1))
    else
        echo -e "${GREEN}✓${NC}"
    fi
    
    # Verificar que se configuró la IP
    echo -n "  Verificando IP del servidor... "
    if grep -q "tu.ip.del.servidor" .env; then
        echo -e "${YELLOW}⚠ Debes configurar SERVER_IP en .env${NC}"
        warnings=$((warnings + 1))
    else
        echo -e "${GREEN}✓${NC}"
    fi
else
    echo -e "${RED}✗ Archivo .env no encontrado${NC}"
    errors=$((errors + 1))
fi

# Verificar estructura de directorios
echo -n "Verificando directorios... "
dirs=("nginx/conf.d" "php" "mysql" "mysql/init" "scripts" "www")
missing_dirs=0
for dir in "${dirs[@]}"; do
    if [ ! -d "$dir" ]; then
        missing_dirs=$((missing_dirs + 1))
    fi
done

if [ $missing_dirs -eq 0 ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗ Faltan $missing_dirs directorios${NC}"
    errors=$((errors + 1))
fi

# Verificar archivos de configuración
echo -n "Verificando archivos de configuración... "
configs=(
    "docker-compose.yml"
    "nginx/nginx.conf"
    "php/php.ini"
    "php/www.conf"
    "mysql/my.cnf"
    "mysql/init/01-init-databases.sql"
)
missing_configs=0
for config in "${configs[@]}"; do
    if [ ! -f "$config" ]; then
        missing_configs=$((missing_configs + 1))
    fi
done

if [ $missing_configs -eq 0 ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗ Faltan $missing_configs archivos de configuración${NC}"
    errors=$((errors + 1))
fi

# Verificar configuraciones de Nginx
echo -n "Verificando virtual hosts de Nginx... "
vhosts=$(ls nginx/conf.d/*.conf 2>/dev/null | wc -l)
if [ $vhosts -ge 2 ]; then
    echo -e "${GREEN}✓ ($vhosts configurados)${NC}"
else
    echo -e "${YELLOW}⚠ Solo $vhosts configurados (mínimo recomendado: 3)${NC}"
    warnings=$((warnings + 1))
fi

# Verificar permisos de scripts
echo -n "Verificando permisos de scripts... "
if [ -x "scripts/setup.sh" ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${YELLOW}⚠ Scripts sin permisos de ejecución${NC}"
    echo "  Ejecuta: chmod +x scripts/*.sh"
    warnings=$((warnings + 1))
fi

# Verificar puertos disponibles
echo -n "Verificando puertos... "
ports_in_use=()
for port in 80 443 21; do
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1 || netstat -tuln 2>/dev/null | grep -q ":$port "; then
        ports_in_use+=($port)
    fi
done

if [ ${#ports_in_use[@]} -eq 0 ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${YELLOW}⚠ Puertos en uso: ${ports_in_use[*]}${NC}"
    echo "  Esto puede causar conflictos. Verifica con: netstat -tuln"
    warnings=$((warnings + 1))
fi

# Verificar memoria disponible
echo -n "Verificando memoria RAM... "
ram_total=$(free -m | awk 'NR==2{print $2}')
if [ $ram_total -ge 7000 ]; then
    echo -e "${GREEN}✓ ${ram_total}MB disponibles${NC}"
elif [ $ram_total -ge 6000 ]; then
    echo -e "${YELLOW}⚠ ${ram_total}MB (cerca del mínimo recomendado)${NC}"
    warnings=$((warnings + 1))
else
    echo -e "${RED}✗ Solo ${ram_total}MB (se recomienda mínimo 8GB)${NC}"
    errors=$((errors + 1))
fi

# Verificar espacio en disco
echo -n "Verificando espacio en disco... "
disk_available=$(df / | awk 'NR==2{print $4}')
disk_available_gb=$((disk_available / 1024 / 1024))
if [ $disk_available_gb -ge 20 ]; then
    echo -e "${GREEN}✓ ${disk_available_gb}GB disponibles${NC}"
elif [ $disk_available_gb -ge 10 ]; then
    echo -e "${YELLOW}⚠ ${disk_available_gb}GB (moderado)${NC}"
    warnings=$((warnings + 1))
else
    echo -e "${RED}✗ Solo ${disk_available_gb}GB (insuficiente)${NC}"
    errors=$((errors + 1))
fi

echo ""
echo "=========================================="
echo "Resumen"
echo "=========================================="

if [ $errors -eq 0 ] && [ $warnings -eq 0 ]; then
    echo -e "${GREEN}✓ Todo listo para el despliegue${NC}"
    echo ""
    echo "Próximos pasos:"
    echo "1. Ejecuta: ./scripts/setup.sh"
    echo "2. Obtén certificados SSL para cada dominio"
    echo "3. Configura cada sitio WordPress"
elif [ $errors -eq 0 ]; then
    echo -e "${YELLOW}⚠ $warnings advertencia(s) encontrada(s)${NC}"
    echo "Puedes continuar, pero revisa las advertencias"
    echo ""
    echo "Para continuar: ./scripts/setup.sh"
else
    echo -e "${RED}✗ $errors error(es) crítico(s) encontrado(s)${NC}"
    if [ $warnings -gt 0 ]; then
        echo -e "${YELLOW}⚠ $warnings advertencia(s) encontrada(s)${NC}"
    fi
    echo ""
    echo "Corrige los errores antes de continuar"
    exit 1
fi

echo ""
