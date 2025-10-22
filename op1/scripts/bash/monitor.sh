#!/bin/bash
# Script de monitoreo del stack WordPress Multisite

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo "=========================================="
echo "  WordPress Multisite - Monitor"
echo "=========================================="
echo ""
date
echo ""

# Estado de contenedores
echo -e "${BLUE}1. ESTADO DE CONTENEDORES${NC}"
echo "=========================================="
docker-compose ps
echo ""

# Uso de recursos por contenedor
echo -e "${BLUE}2. USO DE RECURSOS${NC}"
echo "=========================================="
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}"
echo ""

# Uso de disco
echo -e "${BLUE}3. USO DE DISCO${NC}"
echo "=========================================="
df -h | grep -E '(Filesystem|/$|/var)'
echo ""

# Tamaño de directorios WordPress
echo -e "${BLUE}4. TAMAÑO DE SITIOS${NC}"
echo "=========================================="
for i in {1..10}; do
    if [ -d "www/sitio$i" ]; then
        size=$(du -sh www/sitio$i 2>/dev/null | cut -f1)
        echo "Sitio $i: $size"
    fi
done
echo ""

# MySQL - Tamaño de bases de datos
echo -e "${BLUE}5. BASES DE DATOS${NC}"
echo "=========================================="
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
    docker exec mysql-db mysql -u wpuser -p$DB_PASSWORD -e "
    SELECT 
        table_schema AS 'Database',
        CONCAT(ROUND(SUM(data_length + index_length) / 1024 / 1024, 2), ' MB') AS 'Size'
    FROM information_schema.TABLES
    WHERE table_schema LIKE 'wp_%'
    GROUP BY table_schema
    ORDER BY table_schema;" 2>/dev/null || echo "No se pudo conectar a MySQL"
else
    echo "Archivo .env no encontrado"
fi
echo ""

# Conexiones activas MySQL
echo -e "${BLUE}6. CONEXIONES MYSQL${NC}"
echo "=========================================="
docker exec mysql-db mysql -u root -p$MYSQL_ROOT_PASSWORD -e "SHOW STATUS WHERE variable_name = 'Threads_connected';" 2>/dev/null | tail -n 1 || echo "No disponible"
echo ""

# Logs recientes de Nginx (errores)
echo -e "${BLUE}7. ERRORES RECIENTES (últimas 5 líneas)${NC}"
echo "=========================================="
if [ -f "logs/nginx/error.log" ]; then
    tail -n 5 logs/nginx/error.log 2>/dev/null || echo "Sin errores recientes"
else
    echo "Archivo de log no encontrado"
fi
echo ""

# Estado de certificados SSL
echo -e "${BLUE}8. CERTIFICADOS SSL${NC}"
echo "=========================================="
for cert in certbot/conf/live/*/cert.pem; do
    if [ -f "$cert" ]; then
        domain=$(echo $cert | cut -d'/' -f4)
        expiry=$(docker exec nginx-web openssl x509 -in /etc/letsencrypt/live/$domain/cert.pem -noout -enddate 2>/dev/null | cut -d'=' -f2)
        echo "$domain: expira $expiry"
    fi
done
[ ! -f "certbot/conf/live/*/cert.pem" ] && echo "Sin certificados instalados"
echo ""

# Salud general
echo -e "${BLUE}9. SALUD GENERAL${NC}"
echo "=========================================="

# Verificar contenedores corriendo
running=$(docker-compose ps | grep -c "Up")
total=6  # nginx, php, mysql, phpmyadmin, certbot, ftp

if [ $running -eq $total ]; then
    echo -e "${GREEN}✓ Todos los servicios están corriendo ($running/$total)${NC}"
else
    echo -e "${RED}✗ Algunos servicios están detenidos ($running/$total)${NC}"
fi

# Verificar RAM disponible
ram_available=$(free -m | awk 'NR==2{printf "%.0f", $7}')
if [ $ram_available -gt 2000 ]; then
    echo -e "${GREEN}✓ RAM disponible: ${ram_available}MB${NC}"
elif [ $ram_available -gt 1000 ]; then
    echo -e "${YELLOW}⚠ RAM disponible: ${ram_available}MB (moderada)${NC}"
else
    echo -e "${RED}✗ RAM disponible: ${ram_available}MB (baja)${NC}"
fi

# Verificar disco disponible
disk_available=$(df / | awk 'NR==2{print $4}')
disk_available_gb=$((disk_available / 1024 / 1024))
if [ $disk_available_gb -gt 10 ]; then
    echo -e "${GREEN}✓ Disco disponible: ${disk_available_gb}GB${NC}"
elif [ $disk_available_gb -gt 5 ]; then
    echo -e "${YELLOW}⚠ Disco disponible: ${disk_available_gb}GB (moderado)${NC}"
else
    echo -e "${RED}✗ Disco disponible: ${disk_available_gb}GB (bajo)${NC}"
fi

echo ""
echo "=========================================="
echo "Para logs en tiempo real: docker-compose logs -f"
echo "Para ver un servicio: docker-compose logs [servicio]"
echo "=========================================="
