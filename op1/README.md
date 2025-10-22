# WordPress Multisite con Docker

Stack completo para alojar 10 sitios WordPress con Nginx, PHP-FPM, MySQL, SSL y FTP.

## 📋 Requisitos

- VPS con Ubuntu 24 y 8GB RAM
- Docker y Docker Compose instalados
- Dominios apuntando a la IP del servidor
- Puertos abiertos: 80, 443, 21, 21000-21010

## 🏗️ Arquitectura

```
┌─────────────────────────────────────────┐
│           Nginx (Reverse Proxy)         │
│  - 10 Virtual Hosts                     │
│  - SSL/TLS (Let's Encrypt)              │
│  - Rate Limiting                        │
└─────────────┬───────────────────────────┘
              │
┌─────────────▼───────────────────────────┐
│         PHP-FPM (Shared Pool)           │
│  - WordPress 10 instalaciones           │
│  - OPcache enabled                      │
│  - Memory: 256M por proceso             │
└─────────────┬───────────────────────────┘
              │
┌─────────────▼───────────────────────────┐
│          MySQL 8.0                      │
│  - 10 bases de datos separadas          │
│  - Buffer Pool: 512MB                   │
│  - Query Cache: 64MB                    │
└─────────────────────────────────────────┘
```

## 📁 Estructura de Directorios

```
wordpress-multisite/
├── docker-compose.yml          # Configuración principal
├── .env                        # Variables de entorno (CONFIGURAR)
├── nginx/
│   ├── nginx.conf             # Configuración principal Nginx
│   └── conf.d/                # Virtual hosts
│       ├── sitio1.conf
│       ├── sitio2.conf
│       └── phpmyadmin.conf
├── php/
│   ├── php.ini                # Configuración PHP
│   └── www.conf               # Pool PHP-FPM
├── mysql/
│   ├── my.cnf                 # Configuración MySQL
│   └── init/
│       └── 01-init-databases.sql
├── www/                        # Archivos WordPress
│   ├── sitio1/
│   ├── sitio2/
│   └── ... (hasta sitio10)
├── scripts/
│   ├── setup.sh               # Setup inicial
│   ├── get-ssl.sh             # Obtener certificados SSL
│   ├── backup.sh              # Backup automático
│   └── generate-site-config.sh # Generar configs
├── certbot/                    # Certificados SSL
├── logs/                       # Logs de Nginx
└── backups/                    # Backups automáticos
```

## 🚀 Instalación

### 1. Preparar el entorno

```bash
# Clonar o crear el directorio
mkdir wordpress-multisite && cd wordpress-multisite

# Copiar todos los archivos del proyecto aquí
```

### 2. Configurar variables de entorno

```bash
# Editar .env con tus valores
nano .env
```

**IMPORTANTE:** Cambiar TODAS las contraseñas en `.env`:
- `MYSQL_ROOT_PASSWORD`: Contraseña root de MySQL
- `DB_PASSWORD`: Contraseña para usuario wpuser
- `FTP_PASSWORD`: Contraseña FTP
- `SERVER_IP`: Tu IP del servidor

### 3. Configurar dominios

Edita las configuraciones en `nginx/conf.d/` y reemplaza los dominios de ejemplo con tus dominios reales.

Para generar configs adicionales:
```bash
chmod +x scripts/generate-site-config.sh
./scripts/generate-site-config.sh 3 sitio3.com
./scripts/generate-site-config.sh 4 sitio4.com
# ... etc
```

### 4. Ejecutar setup inicial

```bash
chmod +x scripts/*.sh
./scripts/setup.sh
```

Este script:
- ✅ Verifica dependencias
- ✅ Crea directorios necesarios
- ✅ Descarga WordPress en cada sitio
- ✅ Configura permisos
- ✅ Inicia contenedores

### 5. Obtener certificados SSL

Para cada dominio:

```bash
./scripts/get-ssl.sh sitio1.com admin@sitio1.com
./scripts/get-ssl.sh sitio2.com admin@sitio2.com
# ... repetir para los 10 sitios
```

**Nota:** Los dominios deben apuntar a tu servidor antes de obtener SSL.

### 6. Configurar WordPress

Para cada sitio, crea/edita `www/sitioX/wp-config.php`:

```php
define('DB_NAME', 'wp_sitioX');
define('DB_USER', 'wpuser');
define('DB_PASSWORD', 'tu_password_del_env');
define('DB_HOST', 'mysql');
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', 'utf8mb4_unicode_ci');

// Generar keys en: https://api.wordpress.org/secret-key/1.1/salt/
define('AUTH_KEY',         'generar-aqui');
define('SECURE_AUTH_KEY',  'generar-aqui');
// ... etc

$table_prefix = 'wp_';
define('WP_DEBUG', false);

if ( !defined('ABSPATH') )
    define('ABSPATH', dirname(__FILE__) . '/');

require_once(ABSPATH . 'wp-settings.php');
```

Luego accede a `https://sitioX.com` y completa la instalación web.

## 🔧 Comandos Útiles

### Docker

```bash
# Ver contenedores
docker-compose ps

# Ver logs
docker-compose logs -f
docker-compose logs nginx
docker-compose logs php
docker-compose logs mysql

# Reiniciar servicios
docker-compose restart nginx
docker-compose restart php

# Detener todo
docker-compose down

# Iniciar todo
docker-compose up -d

# Reconstruir contenedores
docker-compose up -d --build
```

### Gestión de sitios

```bash
# Acceder al contenedor PHP
docker exec -it php-fpm bash

# Acceder a MySQL
docker exec -it mysql-db mysql -u root -p

# Ver uso de recursos
docker stats
```

### Backups

```bash
# Backup manual
./scripts/backup.sh

# Configurar backup automático diario (crontab)
crontab -e
# Agregar:
0 2 * * * cd /ruta/a/wordpress-multisite && ./scripts/backup.sh
```

## 🔒 Seguridad

### Implementada

✅ SSL/TLS con Let's Encrypt  
✅ Rate limiting en wp-login.php  
✅ Bloqueo de xmlrpc.php  
✅ Protección de archivos sensibles (.htaccess, wp-config.php)  
✅ Headers de seguridad (X-Frame-Options, X-XSS-Protection)  
✅ HSTS habilitado  
✅ Contraseñas en variables de entorno  

### Recomendaciones adicionales

1. **Firewall (UFW)**
```bash
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 21/tcp
ufw allow 21000:21010/tcp
ufw enable
```

2. **Fail2ban** para proteger SSH y wp-login

3. **Restricción de phpMyAdmin por IP**
Edita `nginx/conf.d/phpmyadmin.conf`:
```nginx
allow 123.456.789.0;  # Tu IP
deny all;
```

4. **Autenticación básica para phpMyAdmin**
```bash
# Crear archivo de contraseñas
docker exec -it nginx-web sh
apk add apache2-utils
htpasswd -c /etc/nginx/.htpasswd admin
exit
```

Descomentar en `phpmyadmin.conf`:
```nginx
auth_basic "Área restringida";
auth_basic_user_file /etc/nginx/.htpasswd;
```

## 📊 Monitoreo

### Recursos del sistema
```bash
# RAM y CPU
htop

# Uso de disco
df -h

# Contenedores
docker stats --no-stream
```

### MySQL
```bash
# Acceder a MySQL
docker exec -it mysql-db mysql -u root -p

# Ver bases de datos y tamaños
SELECT 
  table_schema AS 'Database',
  ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
FROM information_schema.TABLES
GROUP BY table_schema;

# Ver procesos
SHOW PROCESSLIST;
```

### PHP-FPM Status
```bash
# Acceder a status page
curl http://localhost/status?full
```

## 🌐 Acceso a servicios

- **Sitios web:** https://sitio1.com, https://sitio2.com, etc.
- **phpMyAdmin:** https://pma.tu-dominio.com
- **FTP:**
  - Host: IP del servidor
  - Puerto: 21
  - Usuario: ftpuser
  - Password: (del .env)
  - Directorio: /www

## 🐛 Troubleshooting

### Nginx no inicia
```bash
# Ver logs
docker-compose logs nginx

# Verificar sintaxis
docker exec nginx-web nginx -t
```

### PHP-FPM lento
```bash
# Ver procesos activos
docker exec php-fpm ps aux

# Aumentar pm.max_children en php/www.conf
```

### MySQL sin conexión
```bash
# Ver logs
docker-compose logs mysql

# Verificar usuario y permisos
docker exec -it mysql-db mysql -u root -p
SHOW GRANTS FOR 'wpuser'@'%';
```

### Errores SSL
```bash
# Renovar manualmente
docker-compose run --rm certbot renew --force-renewal

# Verificar certificado
openssl s_client -connect sitio1.com:443 -servername sitio1.com
```

## 📈 Optimizaciones

### Para más tráfico

Si un sitio supera 10K visitas/día:

1. **Pool PHP-FPM dedicado** en `php/www.conf`
2. **Nginx cache** con fastcgi_cache
3. **Redis/Memcached** para object cache
4. **CDN** para assets estáticos

### Para ahorrar recursos

Si hay sitios inactivos:

1. Usar un solo pool PHP-FPM más pequeño
2. Reducir `innodb_buffer_pool_size` en MySQL
3. Deshabilitar logs de acceso en sitios con poco tráfico

## 📝 Mantenimiento

### Actualizaciones

```bash
# WordPress (desde cada sitio)
wp core update
wp plugin update --all
wp theme update --all

# Contenedores
docker-compose pull
docker-compose up -d
```

### Limpieza

```bash
# Limpiar logs antiguos
find logs/ -name "*.log" -mtime +30 -delete

# Limpiar backups antiguos (automático en backup.sh)
find backups/ -name "*.tar.gz" -mtime +7 -delete

# Limpiar Docker
docker system prune -a
```

## 💾 Consumo de Recursos Estimado

Con 19K visitas/día totales:

| Servicio | RAM | CPU |
|----------|-----|-----|
| Nginx | ~150MB | <5% |
| PHP-FPM | ~1-1.5GB | 10-20% |
| MySQL | ~600MB | 5-10% |
| phpMyAdmin | ~50MB | <1% |
| FTP | ~20MB | <1% |
| **Total** | **~2.5-3GB** | **20-35%** |

Sobran ~5GB RAM para picos y caché del sistema.

## 📞 Soporte

Para problemas o dudas:
1. Revisa los logs: `docker-compose logs -f`
2. Verifica la configuración: `docker exec nginx-web nginx -t`
3. Consulta la documentación oficial de cada componente

---

**Autor:** Claude  
**Versión:** 1.0  
**Última actualización:** 2025
