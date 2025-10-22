# Generador de Contraseñas Seguras para Servidores

Script en Shell (sh) para generar contraseñas seguras y aleatorias, ideal para administración de servidores Linux/Unix.

## Características

✅ Múltiples niveles de complejidad
✅ Contraseñas memorables basadas en palabras
✅ Análisis de fortaleza de contraseña
✅ Compatible con sh, bash, zsh
✅ No requiere dependencias especiales (usa /dev/urandom)
✅ Colores para mejor visualización

## Instalación

```bash
# Descargar el script
chmod +x generar_password.sh

# Mover a un directorio en tu PATH (opcional)
sudo mv generar_password.sh /usr/local/bin/genpass
```

## Uso Básico

```bash
# Generar 1 contraseña de 16 caracteres (por defecto)
./generar_password.sh

# Ver todas las opciones
./generar_password.sh --help
```

## Ejemplos de Uso

### Contraseña simple (solo letras y números)
```bash
./generar_password.sh -s -l 20
# Ejemplo salida: Kj8mNp2qRt9xLw3vBh4Z
```

### Contraseña compleja (con símbolos especiales)
```bash
./generar_password.sh -c -l 24
# Ejemplo salida: X7k@mP#2qR$9tL&w3vB+h4Z
```

### Contraseña memorable
```bash
./generar_password.sh -m
# Ejemplo salida: Tigre@Luna492
```

### Generar múltiples contraseñas
```bash
./generar_password.sh -n 5 -l 16
# Genera 5 contraseñas de 16 caracteres
```

### Contraseña alfanumérica (sin símbolos)
```bash
./generar_password.sh -a -l 32
# Útil para sistemas que no aceptan símbolos especiales
```

## Opciones Disponibles

| Opción | Descripción | Ejemplo |
|--------|-------------|---------|
| `-l, --longitud NUM` | Longitud de la contraseña | `-l 24` |
| `-n, --numero NUM` | Cantidad de contraseñas | `-n 5` |
| `-s, --simple` | Solo letras y números | `-s` |
| `-c, --compleja` | Con símbolos especiales | `-c` |
| `-m, --memorable` | Basada en palabras | `-m` |
| `-a, --alfanumerica` | Solo alfanuméricos | `-a` |
| `-h, --help` | Mostrar ayuda | `-h` |

## Recomendaciones de Seguridad

### Longitud Recomendada por Uso

| Tipo de Servidor | Longitud Mínima | Ejemplo de Comando |
|------------------|-----------------|-------------------|
| Servidor web | 16 caracteres | `./generar_password.sh -l 16` |
| Base de datos | 20 caracteres | `./generar_password.sh -c -l 20` |
| Root/Admin | 24-32 caracteres | `./generar_password.sh -c -l 32` |
| SSH Keys passphrase | 20-30 caracteres | `./generar_password.sh -l 24` |

### Mejores Prácticas

1. **Nunca reutilices contraseñas** entre diferentes servidores
2. **Usa un gestor de contraseñas** para almacenarlas de forma segura
3. **Cambia las contraseñas periódicamente** (cada 3-6 meses)
4. **Usa autenticación de dos factores** cuando sea posible
5. **Haz backup cifrado** de tus contraseñas

## Casos de Uso Comunes

### 1. Configurar usuario MySQL
```bash
# Generar contraseña para MySQL
PASSWORD=$(./generar_password.sh -l 20 -a | grep -oP '(?<=  ).*')
echo "CREATE USER 'myuser'@'localhost' IDENTIFIED BY '$PASSWORD';" | mysql -u root -p
```

### 2. Crear usuario de sistema con contraseña
```bash
# Generar y asignar contraseña
PASSWORD=$(./generar_password.sh -l 16 -a | grep -oP '(?<=  ).*')
sudo useradd -m usuario_nuevo
echo "usuario_nuevo:$PASSWORD" | sudo chpasswd
echo "Contraseña para usuario_nuevo: $PASSWORD"
```

### 3. Generar archivo con múltiples contraseñas
```bash
# Crear archivo con 10 contraseñas para diferentes servicios
./generar_password.sh -n 10 -l 20 -c > contraseñas_servidores.txt
chmod 600 contraseñas_servidores.txt
```

### 4. Integrar en script de aprovisionamiento
```bash
#!/bin/bash
# Script de configuración automática

MYSQL_PASS=$(./generar_password.sh -l 20 -a | grep -oP '(?<=  ).*')
ADMIN_PASS=$(./generar_password.sh -l 24 -c | grep -oP '(?<=  ).*')

echo "MySQL Password: $MYSQL_PASS" >> /root/credentials.txt
echo "Admin Password: $ADMIN_PASS" >> /root/credentials.txt
chmod 600 /root/credentials.txt
```

## Análisis de Fortaleza

El script analiza automáticamente la fortaleza de cada contraseña generada:

- ✓ Verifica presencia de minúsculas
- ✓ Verifica presencia de mayúsculas
- ✓ Verifica presencia de números
- ✓ Verifica presencia de símbolos
- ✓ Evalúa la longitud total
- ✓ Clasifica el nivel (DÉBIL, MEDIA, FUERTE, MUY FUERTE)

## Tecnología Utilizada

El script utiliza `/dev/urandom` como fuente de aleatoriedad criptográficamente segura, lo que garantiza que las contraseñas generadas sean impredecibles y seguras.

Si `/dev/urandom` no está disponible, el script intenta usar `openssl` como alternativa.

## Compatibilidad

- ✅ Linux (todas las distribuciones)
- ✅ macOS
- ✅ BSD
- ✅ Unix
- ✅ WSL (Windows Subsystem for Linux)

## Solución de Problemas

### Error: "Permission denied"
```bash
chmod +x generar_password.sh
```

### Error: "No se encontró /dev/urandom ni openssl"
```bash
# Instalar openssl
# Ubuntu/Debian:
sudo apt-get install openssl

# CentOS/RHEL:
sudo yum install openssl

# macOS (viene preinstalado)
```

## Seguridad del Script

- No almacena contraseñas en ningún archivo
- No envía datos a través de la red
- Usa fuentes de aleatoriedad criptográficamente seguras
- No requiere permisos de root
- Es completamente open source

## Contribuir

Si encuentras algún bug o tienes sugerencias de mejora, no dudes en reportarlo.

## Licencia

Este script es de código abierto y puede ser usado libremente.

---

**⚠️ Importante:** Recuerda siempre guardar tus contraseñas en un gestor de contraseñas seguro como KeePassXC, Bitwarden, 1Password o similar.
