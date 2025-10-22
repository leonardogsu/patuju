#!/bin/bash
# Script de setup inicial para WordPress Multisite

set -e

echo "==================================="
echo "WordPress Multisite - Setup Inicial"
echo "==================================="
echo ""

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Verificar que estamos en el directorio correcto
if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}Error: docker-compose.yml no encontrado${NC}"
    echo "Ejecuta este script desde el directorio wordpress-multisite/"
    exit 1
fi

# Verificar Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker no está instalado${NC}"
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${RED}Error: Docker Compose no está instalado${NC}"
    exit 1
fi

echo -e "${YELLOW}1. Verificando archivo .env...${NC}"
if [ ! -f ".env" ]; then
    echo -e "${RED}Error: Archivo .env no encontrado${NC}"
    exit 1
fi

# Verificar que se cambiaron las contraseñas
if grep -q "tu_password" .env; then
    echo -e "${RED}¡ADVERTENCIA! Debes cambiar las contraseñas en el archivo .env${NC}"
    echo "Edita el archivo .env antes de continuar"
    exit 1
fi

echo -e "${GREEN}✓ Archivo .env verificado${NC}"

echo ""
echo -e "${YELLOW}2. Creando estructura de directorios...${NC}"

# Crear directorios necesarios
mkdir -p www/{sitio1,sitio2,sitio3,sitio4,sitio5,sitio6,sitio7,sitio8,sitio9,sitio10}
mkdir -p mysql/data
mkdir -p logs/nginx
mkdir -p certbot/{conf,www}
mkdir -p nginx/conf.d

# Establecer permisos
chmod -R 755 www/
chmod -R 755 logs/

echo -e "${GREEN}✓ Directorios creados${NC}"

echo ""
echo -e "${YELLOW}3. Descargando WordPress...${NC}"

# Descargar WordPress en cada directorio si no existe
for i in {1..10}; do
    if [ ! -f "www/sitio$i/wp-config.php" ] && [ ! -f "www/sitio$i/index.php" ]; then
        echo "Descargando WordPress para sitio$i..."
        cd www/sitio$i
        curl -O https://wordpress.org/latest.tar.gz
        tar -xzf latest.tar.gz --strip-components=1
        rm latest.tar.gz
        cd ../..
    else
        echo "WordPress ya existe en sitio$i"
    fi
done

echo -e "${GREEN}✓ WordPress descargado${NC}"

echo ""
echo -e "${YELLOW}4. Configurando permisos...${NC}"

# Permisos para WordPress
chown -R www-data:www-data www/ 2>/dev/null || chown -R 33:33 www/
find www/ -type d -exec chmod 755 {} \;
find www/ -type f -exec chmod 644 {} \;

echo -e "${GREEN}✓ Permisos configurados${NC}"

echo ""
echo -e "${YELLOW}5. Iniciando contenedores...${NC}"

docker-compose up -d

echo ""
echo -e "${GREEN}✓ Contenedores iniciados${NC}"

echo ""
echo "==================================="
echo -e "${GREEN}Setup completado!${NC}"
echo "==================================="
echo ""
echo "Próximos pasos:"
echo ""
echo "1. Configurar DNS apuntando tus dominios a: $(curl -s ifconfig.me)"
echo ""
echo "2. Obtener certificados SSL:"
echo "   ./scripts/get-ssl.sh sitio1.com"
echo "   ./scripts/get-ssl.sh sitio2.com"
echo "   (repetir para cada dominio)"
echo ""
echo "3. Acceder a cada sitio y completar instalación WordPress:"
echo "   https://sitio1.com"
echo "   https://sitio2.com"
echo "   etc..."
echo ""
echo "4. Configurar wp-config.php en cada sitio:"
echo "   - DB_NAME: wp_sitio1, wp_sitio2, etc."
echo "   - DB_USER: wpuser"
echo "   - DB_PASSWORD: (del archivo .env)"
echo "   - DB_HOST: mysql"
echo ""
echo "5. Acceder a phpMyAdmin: https://pma.tu-dominio.com"
echo ""
echo "6. Acceder a FTP:"
echo "   - Host: $(curl -s ifconfig.me)"
echo "   - Puerto: 21"
echo "   - Usuario: ftpuser"
echo "   - Password: (del archivo .env)"
echo ""
echo "Para ver logs: docker-compose logs -f"
echo "Para detener: docker-compose down"
echo ""
