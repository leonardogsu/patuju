# Script de Instalación de Docker y Docker Compose

Este script automatiza la instalación de Docker Engine y Docker Compose en Ubuntu 24.04.

## Características

- ✅ Instalación desatendida (sin interacción del usuario)
- ✅ Actualización del sistema
- ✅ Instalación de Docker Engine
- ✅ Instalación de Docker Compose (plugin)
- ✅ Configuración automática del usuario
- ✅ Verificación de la instalación
- ✅ Prueba con contenedor hello-world
- ✅ Manejo de errores
- ✅ Mensajes informativos con colores

## Requisitos

- Ubuntu 24.04 LTS
- Acceso root o permisos sudo
- Conexión a Internet

## Uso

### Opción 1: Descarga y ejecución directa

```bash
# Descargar el script
wget https://tu-servidor.com/install_docker.sh

# Dar permisos de ejecución
chmod +x install_docker.sh

# Ejecutar con sudo
sudo ./install_docker.sh
```

### Opción 2: Ejecución en una línea

```bash
curl -fsSL https://tu-servidor.com/install_docker.sh | sudo bash
```

### Opción 3: Desde el archivo local

```bash
sudo bash install_docker.sh
```

## Qué hace el script

1. Verifica permisos de root/sudo
2. Actualiza el sistema (`apt update && apt upgrade`)
3. Instala dependencias necesarias
4. Elimina versiones antiguas de Docker (si existen)
5. Configura el repositorio oficial de Docker
6. Instala Docker Engine, CLI, containerd y plugins
7. Inicia y habilita el servicio Docker
8. Añade el usuario actual al grupo docker
9. Verifica la instalación
10. Ejecuta un contenedor de prueba (hello-world)

## Después de la instalación

**Importante:** Para usar Docker sin sudo, debes cerrar sesión e iniciar sesión nuevamente, o ejecutar:

```bash
newgrp docker
```

## Verificar la instalación

```bash
# Ver versión de Docker
docker --version

# Ver versión de Docker Compose
docker compose version

# Probar Docker
docker run hello-world

# Ver estado del servicio
sudo systemctl status docker
```

## Ejemplo de uso con Docker Compose

Crea un archivo `docker-compose.yml`:

```yaml
version: '3.8'

services:
  web:
    image: nginx:latest
    ports:
      - "8080:80"
```

Ejecuta:

```bash
docker compose up -d
```

## Solución de problemas

### Error de permisos
Si obtienes errores de permisos después de la instalación:
```bash
sudo usermod -aG docker $USER
newgrp docker
```

### Docker no inicia
```bash
sudo systemctl start docker
sudo systemctl status docker
```

### Verificar logs
```bash
sudo journalctl -u docker.service
```

## Desinstalación (si es necesario)

```bash
sudo apt purge docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd
```

## Compatibilidad

- ✅ Ubuntu 24.04 LTS
- ✅ Ubuntu 22.04 LTS
- ✅ Ubuntu 20.04 LTS
- ⚠️ Otras distribuciones: puede requerir ajustes

## Soporte

Este script instala las últimas versiones estables de Docker y Docker Compose desde los repositorios oficiales de Docker.

## Licencia

Este script es de libre uso y distribución.