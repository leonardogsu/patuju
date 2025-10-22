# 🚀 Guía de Inicio Rápido

## Instalación en 5 Minutos

### Prerequisitos
- Ubuntu 24.04 LTS recién instalado
- Acceso root o sudo
- Conexión a internet

### Pasos

**1. Descargar el proyecto**
```bash
cd ~
# Si tienes git instalado:
git clone <URL-DEL-REPOSITORIO>

# O descarga y descomprime:
# wget <URL>/wordpress-multisite-auto.tar.gz
# tar -xzf wordpress-multisite-auto.tar.gz

cd wordpress-multisite-auto
```

**2. Ejecutar el instalador**
```bash
chmod +x auto-install.sh
sudo ./auto-install.sh
```

**3. Responder las preguntas**
El instalador te preguntará:
- IP del servidor (se detecta automáticamente)
- Dominios a configurar
- Si quieres phpMyAdmin
- Si quieres servidor FTP
- Si quieres backup automático

**4. Esperar la instalación**
El proceso toma entre 5-10 minutos dependiendo de tu conexión.

**5. Configurar DNS**
Apunta los dominios a la IP de tu servidor:
```
Tipo A -> TU_IP_DEL_SERVIDOR
```

**6. Obtener certificados SSL**
Una vez que los DNS estén activos (puede tardar hasta 24h):
```bash
cd /opt/wordpress-multisite
sudo ./scripts/setup-ssl.sh
```

**7. Configurar WordPress**
Visita cada dominio y completa la instalación:
```
http://tu-dominio.com/wp-admin/install.php
```

## ✅ ¡Listo!

Tu plataforma WordPress multi-sitio está funcionando.

## 🎯 Gestión Diaria

**Ver estado:**
```bash
cd /opt/wordpress-multisite
sudo ./manage.sh
```

**Crear backup:**
```bash
cd /opt/wordpress-multisite
sudo ./scripts/backup.sh
```

**Ver logs:**
```bash
cd /opt/wordpress-multisite
docker compose logs -f
```

## 📚 Más Información

Ver **README.md** para documentación completa.

## 🆘 Problemas Comunes

### Los contenedores no inician
```bash
sudo systemctl restart docker
cd /opt/wordpress-multisite
docker compose up -d
```

### Error 502 en WordPress
```bash
cd /opt/wordpress-multisite
docker compose restart php
```

### SSL no funciona
1. Verifica que los DNS apunten correctamente: `dig +short tu-dominio.com`
2. Espera 24h para propagación de DNS
3. Vuelve a ejecutar: `sudo ./scripts/setup-ssl.sh`

### Olvidé las contraseñas
```bash
cat /opt/wordpress-multisite/.credentials
```

---

**¿Necesitas ayuda?** Consulta el README.md o abre un issue en GitHub.
