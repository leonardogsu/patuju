# WordPress Multi-Site - Instalación Automatizada

Sistema completo de WordPress multi-sitio con Docker, completamente automatizado para Ubuntu 24.04 LTS.

## 🚀 Características

- ✅ **Instalación 100% automatizada** desde Ubuntu 24.04 limpio
- ✅ **Multi-sitio**: Soporta múltiples dominios WordPress independientes
- ✅ **Docker Compose**: Arquitectura containerizada
- ✅ **Nginx**: Servidor web de alto rendimiento
- ✅ **PHP 8.2-FPM**: Última versión estable
- ✅ **MySQL 8.0**: Base de datos robusta
- ✅ **Let's Encrypt**: Certificados SSL automáticos
- ✅ **phpMyAdmin**: Gestión de bases de datos (opcional)
- ✅ **Servidor FTP**: Para transferencia de archivos (opcional)
- ✅ **Backup automático**: Sistema de respaldo programado
- ✅ **Firewall UFW**: Seguridad del servidor

## 📋 Requisitos Mínimos

- **Sistema Operativo**: Ubuntu 24.04 LTS
- **RAM**: 8GB recomendado (mínimo 4GB)
- **Disco**: 20GB libres
- **Red**: IP pública
- **Acceso**: Root o sudo

## 🎯 Instalación Rápida (Opción 1)

Para una instalación completamente automatizada:

```bash
# 1. Descargar el proyecto
git clone https://github.com/tu-usuario/wordpress-multisite-auto.git
cd wordpress-multisite-auto

# 2. Dar permisos de ejecución
chmod +x auto-install.sh

# 3. Ejecutar instalador (como root)
sudo ./auto-install.sh
```

El script te guiará paso a paso solicitando:
- IP del servidor (se detecta automáticamente)
- Dominios que deseas configurar
- Opciones de phpMyAdmin y FTP
- Configuración de backup automático

**¡Eso es todo!** El script hará todo el resto automáticamente.

## 🛠️ Instalación Manual (Opción 2)

Si prefieres más control sobre el proceso:

### Paso 1: Preparar el servidor

```bash
# Actualizar sistema
sudo apt update && sudo apt upgrade -y

# Instalar Git
sudo apt install -y git

# Clonar repositorio
git clone https://github.com/tu-usuario/wordpress-multisite-auto.git
cd wordpress-multisite-auto
```

### Paso 2: Ejecutar instalador base

```bash
sudo ./install.sh
```

### Paso 3: Generar configuraciones

```bash
cd /opt/wordpress-multisite
sudo ./scripts/generate-config.sh
```

### Paso 4: Instalar WordPress

```bash
sudo ./scripts/setup.sh
```

### Paso 5: Configurar SSL (después de configurar DNS)

```bash
sudo ./scripts/setup-ssl.sh
```

## 📁 Estructura del Proyecto

```
/opt/wordpress-multisite/
├── .env                          # Variables de entorno
├── .credentials                  # Archivo con credenciales (¡proteger!)
├── docker-compose.yml            # Configuración de contenedores
├── nginx/
│   ├── nginx.conf               # Configuración principal Nginx
│   └── conf.d/                  # Virtual hosts por dominio
│       ├── dominio1.conf
│       ├── dominio2.conf
│       └── ...
├── php/
│   ├── php.ini                  # Configuración PHP
│   └── www.conf                 # Configuración PHP-FPM
├── mysql/
│   ├── my.cnf                   # Configuración MySQL
│   ├── init/                    # Scripts de inicialización
│   └── data/                    # Datos de MySQL
├── www/
│   ├── sitio1/                  # WordPress sitio 1
│   ├── sitio2/                  # WordPress sitio 2
│   └── ...
├── certbot/
│   ├── conf/                    # Certificados SSL
│   └── www/                     # Desafíos ACME
├── backups/                     # Backups automáticos
├── logs/
│   └── nginx/                   # Logs de Nginx
└── scripts/
    ├── generate-config.sh       # Genera configuraciones
    ├── setup.sh                 # Setup de WordPress
    ├── setup-ssl.sh             # Configura SSL
    └── backup.sh                # Sistema de backup
```

## 🔧 Gestión del Sistema

### Comandos Docker

```bash
# Ver estado de contenedores
docker compose ps

# Ver logs
docker compose logs -f

# Ver logs de un servicio específico
docker compose logs -f nginx

# Reiniciar todos los servicios
docker compose restart

# Reiniciar un servicio específico
docker compose restart nginx

# Detener servicios
docker compose stop

# Iniciar servicios
docker compose start

# Detener y eliminar contenedores
docker compose down

# Reconstruir y reiniciar
docker compose up -d --build
```

### Gestión de WordPress

Cada sitio WordPress es independiente y se encuentra en:
```
/opt/wordpress-multisite/www/sitioX/
```

Puedes acceder vía:
- **Web**: http://tu-dominio.com
- **FTP**: ftpuser@tu-servidor.com (si está habilitado)
- **Directo**: Editando archivos en el servidor

### Base de Datos

Acceso a MySQL:
```bash
# Entrar a MySQL desde el host
docker compose exec mysql mysql -uroot -p

# Usar un comando directo
docker compose exec mysql mysql -uroot -p"PASSWORD" -e "SHOW DATABASES;"
```

Bases de datos creadas:
- `wp_sitio1` - Para el primer dominio
- `wp_sitio2` - Para el segundo dominio
- etc.

### phpMyAdmin (si está instalado)

Accede desde: `http://tu-dominio.com/phpmyadmin`

Credenciales:
- Usuario: `wpuser`
- Contraseña: (ver archivo `.credentials`)

## 🔒 Certificados SSL

### Configuración Inicial

```bash
cd /opt/wordpress-multisite
sudo ./scripts/setup-ssl.sh
```

El script:
1. Solicita tu email
2. Obtiene certificados para todos los dominios
3. Configura HTTPS en Nginx
4. Recarga la configuración

### Renovación Automática

Los certificados se renuevan automáticamente cada 12 horas mediante el contenedor `certbot`.

Para forzar renovación:
```bash
docker compose run --rm certbot renew
```

### Verificar Certificados

```bash
docker compose run --rm certbot certificates
```

## 💾 Sistema de Backup

### Backup Manual

```bash
cd /opt/wordpress-multisite
sudo ./scripts/backup.sh
```

El script crea backup de:
- Todas las bases de datos MySQL
- Archivos WordPress (wp-content)
- Configuraciones del sistema

Los backups se guardan en: `/opt/wordpress-multisite/backups/`

### Backup Automático

Si configuraste backup automático durante la instalación, se ejecuta diariamente a las 2:00 AM.

Para verificar:
```bash
crontab -l
```

Para ver logs de backup:
```bash
tail -f /opt/wordpress-multisite/logs/backup.log
```

### Restaurar un Backup

1. **Base de datos**:
```bash
cd /opt/wordpress-multisite
gunzip backups/FECHA/wp_sitioX.sql.gz
docker compose exec -T mysql mysql -uroot -p"PASSWORD" wp_sitioX < backups/FECHA/wp_sitioX.sql
```

2. **Archivos**:
```bash
cd /opt/wordpress-multisite
tar -xzf backups/FECHA/sitioX_files.tar.gz -C www/sitioX/
```

## 🔥 Firewall

El firewall UFW está configurado automáticamente con:

```bash
# Ver estado
sudo ufw status

# Puertos abiertos por defecto:
# - 22 (SSH)
# - 80 (HTTP)
# - 443 (HTTPS)
# - 21 y 21000-21010 (FTP, si está habilitado)
```

Para añadir reglas:
```bash
sudo ufw allow PUERTO/tcp
sudo ufw reload
```

## 🐛 Solución de Problemas

### Los contenedores no inician

```bash
# Ver logs detallados
docker compose logs

# Verificar sintaxis de docker-compose.yml
docker compose config

# Reiniciar Docker
sudo systemctl restart docker
docker compose up -d
```

### WordPress muestra error de base de datos

```bash
# Verificar que MySQL esté corriendo
docker compose ps mysql

# Verificar logs de MySQL
docker compose logs mysql

# Verificar credenciales en wp-config.php
cat www/sitio1/wp-config.php | grep DB_
```

### Nginx muestra error 502

```bash
# Verificar PHP-FPM
docker compose ps php

# Ver logs de PHP
docker compose logs php

# Reiniciar PHP
docker compose restart php
```

### Error de permisos en WordPress

```bash
# Ajustar permisos
sudo chown -R www-data:www-data /opt/wordpress-multisite/www/
sudo find /opt/wordpress-multisite/www/ -type d -exec chmod 755 {} \;
sudo find /opt/wordpress-multisite/www/ -type f -exec chmod 644 {} \;
```

### SSL no funciona

1. Verifica que los DNS apunten correctamente:
```bash
dig +short tu-dominio.com
```

2. Verifica que los certificados existan:
```bash
ls -la /opt/wordpress-multisite/certbot/conf/live/
```

3. Revisa logs de certbot:
```bash
docker compose logs certbot
```

### Puerto 80 o 443 ya en uso

```bash
# Ver qué proceso usa el puerto
sudo lsof -i :80
sudo lsof -i :443

# Detener Apache si está instalado
sudo systemctl stop apache2
sudo systemctl disable apache2
```

## 📊 Monitoreo

### Ver uso de recursos

```bash
# Ver recursos de contenedores
docker stats

# Ver uso de disco
df -h

# Ver memoria
free -h

# Ver logs del sistema
journalctl -u docker -f
```

### Logs importantes

```bash
# Logs de Nginx
docker compose logs nginx

# Logs de acceso
tail -f logs/nginx/access.log

# Logs de errores
tail -f logs/nginx/error.log

# Logs de MySQL
docker compose logs mysql

# Logs de PHP
docker compose logs php
```

## 🔄 Actualizaciones

### Actualizar WordPress

```bash
# Opción 1: Desde el panel de WordPress
# Ir a Dashboard > Actualizaciones

# Opción 2: Manual
cd /opt/wordpress-multisite/www/sitioX
# Hacer backup primero
sudo ../../../scripts/backup.sh
# Actualizar archivos manualmente
```

### Actualizar contenedores Docker

```bash
cd /opt/wordpress-multisite

# Descargar nuevas imágenes
docker compose pull

# Reiniciar con nuevas imágenes
docker compose up -d
```

## 🔐 Seguridad

### Mejores Prácticas

1. **Cambia las credenciales predeterminadas**:
```bash
# Cambiar password de MySQL
docker compose exec mysql mysql -uroot -p"OLDPASS" -e "ALTER USER 'root'@'%' IDENTIFIED BY 'NEWPASS';"
```

2. **Mantén el sistema actualizado**:
```bash
sudo apt update && sudo apt upgrade -y
```

3. **Usa contraseñas fuertes** en WordPress

4. **Instala plugins de seguridad**:
   - Wordfence Security
   - iThemes Security
   - Sucuri Security

5. **Configura backups regulares**

6. **Revisa logs periódicamente**

7. **Limita intentos de login**

### Hardening adicional

```bash
# Desactivar root login por SSH
sudo nano /etc/ssh/sshd_config
# PermitRootLogin no
sudo systemctl restart sshd

# Instalar fail2ban
sudo apt install fail2ban -y
sudo systemctl enable fail2ban
```

## 📚 Recursos Adicionales

- [Documentación oficial de WordPress](https://wordpress.org/documentation/)
- [Documentación de Docker](https://docs.docker.com/)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)

## 🆘 Soporte

Si encuentras problemas:

1. Revisa los logs: `docker compose logs`
2. Consulta la sección de solución de problemas
3. Verifica el log de instalación: `/var/log/wordpress-multisite-install.log`
4. Abre un issue en GitHub

## 📝 Licencia

Este proyecto está bajo licencia MIT. Ver archivo `LICENSE` para más detalles.

## 🙏 Contribuciones

Las contribuciones son bienvenidas. Por favor:

1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

## ✅ Checklist Post-Instalación

- [ ] Servidor actualizado y Docker instalado
- [ ] Contenedores corriendo correctamente
- [ ] DNS apuntando al servidor
- [ ] Certificados SSL obtenidos
- [ ] WordPress instalado en cada sitio
- [ ] Backups automáticos configurados
- [ ] Contraseñas cambiadas y guardadas
- [ ] Plugins de seguridad instalados
- [ ] Firewall configurado
- [ ] Monitoreo configurado

---

**¡Disfruta de tu nueva plataforma WordPress multi-sitio!** 🎉
