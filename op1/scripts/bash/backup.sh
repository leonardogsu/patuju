#!/bin/bash
# Script de backup para WordPress Multisite

set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

BACKUP_DIR="backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="backup_$DATE"

echo "==================================="
echo "Backup WordPress Multisite"
echo "==================================="
echo "Fecha: $(date)"
echo ""

# Crear directorio de backups
mkdir -p $BACKUP_DIR/$BACKUP_NAME

echo -e "${YELLOW}1. Haciendo backup de archivos...${NC}"

# Backup de archivos WordPress
tar -czf $BACKUP_DIR/$BACKUP_NAME/wordpress-files.tar.gz www/ 2>/dev/null
echo -e "${GREEN}✓ Archivos respaldados${NC}"

echo ""
echo -e "${YELLOW}2. Haciendo backup de bases de datos...${NC}"

# Cargar contraseña de .env
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Backup de cada base de datos
for i in {1..10}; do
    echo "Respaldando wp_sitio$i..."
    docker exec mysql-db mysqldump \
        -u wpuser \
        -p$DB_PASSWORD \
        wp_sitio$i > $BACKUP_DIR/$BACKUP_NAME/wp_sitio$i.sql
done

echo -e "${GREEN}✓ Bases de datos respaldadas${NC}"

echo ""
echo -e "${YELLOW}3. Comprimiendo backup...${NC}"

cd $BACKUP_DIR
tar -czf $BACKUP_NAME.tar.gz $BACKUP_NAME/
rm -rf $BACKUP_NAME/
cd ..

BACKUP_SIZE=$(du -h $BACKUP_DIR/$BACKUP_NAME.tar.gz | cut -f1)

echo -e "${GREEN}✓ Backup comprimido${NC}"

echo ""
echo "==================================="
echo -e "${GREEN}Backup completado!${NC}"
echo "==================================="
echo ""
echo "Archivo: $BACKUP_DIR/$BACKUP_NAME.tar.gz"
echo "Tamaño: $BACKUP_SIZE"
echo ""
echo "Para restaurar:"
echo "1. Extrae el archivo .tar.gz"
echo "2. Restaura los archivos en www/"
echo "3. Importa cada .sql a su base de datos correspondiente"
echo ""

# Limpiar backups antiguos (mantener últimos 7 días)
echo -e "${YELLOW}Limpiando backups antiguos...${NC}"
find $BACKUP_DIR -name "backup_*.tar.gz" -mtime +7 -delete
echo -e "${GREEN}✓ Limpieza completada${NC}"
echo ""
