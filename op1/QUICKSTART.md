# 🚀 Guía de Inicio Rápido

## Paso 1: Preparación (5 minutos)

```bash
# 1. Descargar y descomprimir el proyecto
cd /opt
# (copiar archivos del proyecto aquí)

# 2. Editar variables de entorno
nano .env

# CAMBIAR OBLIGATORIAMENTE:
# - MYSQL_ROOT_PASSWORD
# - DB_PASSWORD
# - FTP_PASSWORD
# - SERVER_IP (tu IP pública)
# - Todos los dominios (DOMAIN_1, DOMAIN_2, etc.)
```

## Paso 2: Verificación (2 minutos)

```bash
# Dar permisos a scripts
chmod +x scripts/*.sh

# Verificar que todo está OK
./scripts/verify.sh
```

## Paso 3: Despliegue (10 minutos)

```bash
# Ejecutar setup automático
./scripts/setup.sh
```

Este script:
- ✅ Crea directorios
- ✅ Descarga WordPress
- ✅ Configura permisos
- ✅ Inicia contenedores

## Paso 4: Configurar DNS

Para cada dominio, crea un registro A apuntando a tu IP:

```
Tipo: A
Nombre: @
Valor: TU_IP_DEL_SERVIDOR
TTL: 300

Tipo: A
Nombre: www
Valor: TU_IP_DEL_SERVIDOR
TTL: 300
```

Espera 5-15 minutos para propagación DNS.

## Paso 5: Obtener SSL (5 minutos cada dominio)

```bash
# Para cada dominio:
./scripts/get-ssl.sh sitio1.com admin@sitio1.com
./scripts/get-ssl.sh sitio2.com admin@sitio2.com
# ... repetir para los 10 sitios
```

## Paso 6: Configurar WordPress (5 minutos por sitio)

Para cada sitio (sitio1 a sitio10):

```bash
# 1. Copiar plantilla de configuración
cp wp-config-sample.php www/sitio1/wp-config.php

# 2. Editar configuración
nano www/sitio1/wp-config.php
```

Cambiar:
- `DB_NAME`: `wp_sitio1` (wp_sitio2, wp_sitio3, etc.)
- `DB_PASSWORD`: (tu password del .env)
- Generar claves en: https://api.wordpress.org/secret-key/1.1/salt/

```bash
# 3. Establecer permisos
chown -R www-data:www-data www/sitio1/
```

Luego acceder a `https://sitio1.com` y completar instalación.

## Paso 7: Acceso a servicios

### Sitios web
- https://sitio1.com
- https://sitio2.com
- ... etc

### phpMyAdmin
https://pma.tu-dominio.com

### FTP
- Host: TU_IP
- Puerto: 21
- Usuario: ftpuser
- Password: (del .env)

## Comandos útiles

```bash
# Ver estado
docker-compose ps

# Ver logs
docker-compose logs -f

# Reiniciar servicio
docker-compose restart nginx

# Monitor completo
./scripts/monitor.sh

# Backup
./scripts/backup.sh

# Generar configuración de nuevo sitio
./scripts/generate-site-config.sh 3 sitio3.com
```

## Troubleshooting rápido

### Los contenedores no inician
```bash
docker-compose logs
docker-compose down
docker-compose up -d
```

### Error de SSL
```bash
# Verificar que DNS apunta correctamente
nslookup sitio1.com

# Reintentar certificado
./scripts/get-ssl.sh sitio1.com
```

### WordPress muestra error de conexión a BD
```bash
# Verificar que MySQL está corriendo
docker exec -it mysql-db mysql -u wpuser -p

# Verificar wp-config.php tiene:
# DB_HOST: mysql (no localhost)
```

### Acceso denegado phpMyAdmin
```bash
# Editar nginx/conf.d/phpmyadmin.conf
# Permitir tu IP o activar auth básica
docker-compose restart nginx
```

## Próximos pasos

1. Instalar plugins de seguridad (Wordfence, iThemes Security)
2. Configurar backups automáticos con cron
3. Optimizar imágenes (WP Smush, ShortPixel)
4. Configurar CDN (Cloudflare)
5. Instalar plugin de caché (WP Super Cache, W3 Total Cache)

## Recursos adicionales

- [Documentación completa](README.md)
- [WordPress Codex](https://codex.wordpress.org/)
- [Nginx Docs](https://nginx.org/en/docs/)
- [Docker Docs](https://docs.docker.com/)

---

**Tiempo total estimado:** 1-2 horas para configuración completa
**Dificultad:** Media
**Conocimientos necesarios:** Linux básico, Docker básico
