# Guía para Desarrolladores

Esta guía es para desarrolladores que desean contribuir, modificar o extender este proyecto.

## 📁 Estructura del Proyecto

```
wordpress-multisite-automated/
├── auto-install.sh          # Script principal de instalación (punto de entrada)
├── check-system.sh          # Verificación de requisitos del sistema
├── README.md                # Documentación completa del usuario
├── QUICKSTART.md            # Guía rápida de inicio
├── CHANGELOG.md             # Historial de versiones
├── LICENSE                  # Licencia MIT
├── INFO.txt                 # Información del proyecto
├── .env.example             # Ejemplo de archivo de configuración
├── .gitignore              # Archivos a ignorar en Git
└── scripts/                 # Scripts auxiliares
    ├── install.sh           # Instalador base del sistema
    ├── generate-config.sh   # Generador de configuraciones
    ├── setup.sh             # Descarga e instalación de WordPress
    ├── setup-ssl.sh         # Configuración de certificados SSL
    ├── backup.sh            # Sistema de backup
    ├── manage.sh            # Gestor interactivo
    └── uninstall.sh         # Desinstalador completo
```

## 🔄 Flujo de Instalación

1. **Usuario ejecuta**: `sudo ./auto-install.sh`
2. **auto-install.sh**:
   - Verifica requisitos del sistema
   - Solicita información (IP, dominios, opciones)
   - Actualiza el sistema Ubuntu
   - Instala Docker y Docker Compose
   - Configura firewall UFW
   - Crea estructura de directorios
   - Genera credenciales seguras
   - Llama a `generate-config.sh`
   - Llama a `setup.sh`
   - Configura cron (si se solicita)
3. **generate-config.sh**:
   - Genera docker-compose.yml
   - Genera configuraciones de Nginx
   - Genera configuraciones de PHP
   - Genera configuraciones de MySQL
   - Genera .gitignore
4. **setup.sh**:
   - Descarga WordPress
   - Extrae WordPress en cada sitio
   - Genera wp-config.php con salt keys
   - Ajusta permisos
   - Inicia contenedores Docker
5. **setup-ssl.sh** (ejecutado manualmente después):
   - Obtiene certificados Let's Encrypt
   - Configura HTTPS en Nginx
   - Recarga Nginx

## 🛠️ Modificar Scripts

### Añadir un Nuevo Servicio Docker

Edita `scripts/generate-config.sh`:

```bash
# En la sección de docker-compose.yml, añade:
cat >> docker-compose.yml << 'NEWSERVICE'

  mi-servicio:
    image: mi-imagen:latest
    container_name: mi-servicio
    ports:
      - "PUERTO:PUERTO"
    volumes:
      - ./ruta:/ruta
    networks:
      - wordpress-network
    restart: unless-stopped
NEWSERVICE
```

### Añadir Verificaciones al Sistema

Edita `check-system.sh`:

```bash
# Añade tu verificación
echo -n "Verificando mi requisito... "
if [ condición ]; then
    echo -e "${GREEN}✓ OK${NC}"
else
    echo -e "${RED}✗ ERROR${NC}"
    errors=$((errors + 1))
fi
```

### Modificar Configuración de Nginx

Edita `scripts/generate-config.sh` en la sección de virtual hosts:

```bash
# Añade directivas personalizadas en la sección del vhost
location /mi-ruta {
    # Tu configuración
}
```

### Añadir Funcionalidad al Gestor

Edita `scripts/manage.sh`:

```bash
# Añade una nueva opción al menú
case $option in
    X)
        mi_nueva_funcion
        pause
        ;;
esac
```

## 🧪 Testing

### Probar en Máquina Virtual

Recomendado: usar VirtualBox o VMware con Ubuntu 24.04:

```bash
# 1. Crear VM con Ubuntu 24.04
# 2. Clonar el proyecto
git clone <repo>
cd wordpress-multisite-automated

# 3. Ejecutar verificación
sudo ./check-system.sh

# 4. Ejecutar instalación
sudo ./auto-install.sh

# 5. Verificar resultado
cd /opt/wordpress-multisite
docker compose ps
```

### Probar Scripts Individuales

```bash
# Probar generador de config
cd /opt/wordpress-multisite
./scripts/generate-config.sh

# Probar backup
./scripts/backup.sh

# Probar gestor
./scripts/manage.sh
```

## 🐛 Debug

### Habilitar modo debug

Añade al inicio de cualquier script:

```bash
set -x  # Mostrar comandos ejecutados
set -e  # Salir en error
```

### Ver logs detallados

```bash
# Logs de instalación
tail -f /var/log/wordpress-multisite-install.log

# Logs de Docker
docker compose logs -f

# Logs de Nginx
tail -f /opt/wordpress-multisite/logs/nginx/error.log
```

## 📝 Convenciones de Código

### Bash Scripts

1. **Shebang**: Usar `#!/bin/bash`
2. **Set options**: `set -e` para salir en error
3. **Colores**: Usar variables definidas al inicio
4. **Funciones**: Nombres descriptivos en snake_case
5. **Comentarios**: Explicar secciones complejas
6. **Logging**: Usar funciones log(), error(), warning()

Ejemplo:

```bash
#!/bin/bash
set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Función
my_function() {
    local param=$1
    echo -e "${GREEN}[INFO]${NC} Procesando: $param"
    # Tu código aquí
}

# Main
my_function "valor"
```

### Nombres de Variables

- Variables de entorno: `UPPER_CASE`
- Variables locales: `lower_case`
- Arrays: `plural_names`
- Constantes: `UPPER_CASE`

### Estructura de Archivos

```bash
#!/bin/bash

# 1. Shebang y set options
# 2. Comentario del propósito del script
# 3. Definición de colores
# 4. Definición de constantes
# 5. Funciones auxiliares
# 6. Función principal
# 7. Ejecución
```

## 🔐 Seguridad

### Manejo de Contraseñas

```bash
# ✓ CORRECTO - generar con pwgen
PASSWORD=$(pwgen -s 32 1)

# ✗ INCORRECTO - hardcodear
PASSWORD="password123"
```

### Permisos de Archivos

```bash
# Archivos con credenciales
chmod 600 .env
chmod 600 .credentials

# Scripts ejecutables
chmod +x scripts/*.sh

# Directorios WordPress
chown -R www-data:www-data www/
```

## 📦 Release Process

### 1. Actualizar Versión

Edita `INFO.txt` y `CHANGELOG.md`:

```bash
VERSIÓN: X.Y.Z
```

### 2. Probar en VM Limpia

```bash
# Prueba completa en Ubuntu 24.04 limpio
sudo ./auto-install.sh
# Verificar todos los sitios
# Verificar SSL
# Verificar backup
```

### 3. Crear Tag

```bash
git tag -a vX.Y.Z -m "Release X.Y.Z"
git push origin vX.Y.Z
```

### 4. Crear Release en GitHub

- Título: `vX.Y.Z - Nombre descriptivo`
- Descripción: Copiar de CHANGELOG.md
- Adjuntar tarball del proyecto

## 🤝 Contribuir

### Fork y Pull Request

1. Fork el repositorio
2. Crea una rama: `git checkout -b feature/mi-feature`
3. Haz tus cambios
4. Prueba exhaustivamente
5. Commit: `git commit -m "Add: mi feature"`
6. Push: `git push origin feature/mi-feature`
7. Crea Pull Request

### Commit Messages

Formato:

```
Tipo: Descripción corta

Descripción larga si es necesario.

Relacionado con: #issue
```

Tipos:
- `Add:` Nueva funcionalidad
- `Fix:` Corrección de bug
- `Update:` Actualización de funcionalidad existente
- `Remove:` Eliminación de código
- `Refactor:` Refactorización sin cambio funcional
- `Docs:` Solo documentación
- `Test:` Añadir o modificar tests
- `Style:` Cambios de formato

## 📚 Recursos

- [Bash Guide](https://mywiki.wooledge.org/BashGuide)
- [Docker Documentation](https://docs.docker.com/)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [WordPress Codex](https://codex.wordpress.org/)

## 🐛 Reportar Bugs

Incluye:
1. Versión del proyecto
2. Sistema operativo y versión
3. Pasos para reproducir
4. Comportamiento esperado
5. Comportamiento actual
6. Logs relevantes

## 💡 Sugerir Features

1. Abre un issue con etiqueta "enhancement"
2. Describe el caso de uso
3. Propón una implementación
4. Discute con maintainers

## 📄 Licencia

MIT License - Ver LICENSE para más detalles.

---

**¿Preguntas?** Abre un issue en GitHub o contacta a los maintainers.
