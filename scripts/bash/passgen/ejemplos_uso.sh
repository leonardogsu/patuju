#!/bin/sh
#
# Ejemplos prácticos de uso del generador de contraseñas
# Estos scripts muestran cómo integrar el generador en tareas comunes
#

# ===========================================
# 1. CREAR USUARIO DE BASE DE DATOS MYSQL
# ===========================================

crear_usuario_mysql() {
    echo "=== Crear Usuario MySQL con Contraseña Segura ==="
    
    # Generar contraseña
    PASSWORD=$(sh generar_password.sh -l 20 -a | grep -A1 "Contraseña" | tail -1 | sed 's/^[[:space:]]*//' | sed 's/\x1b\[[0-9;]*m//g')
    
    USUARIO="nuevo_usuario"
    DATABASE="mi_base_datos"
    
    echo "Usuario: $USUARIO"
    echo "Contraseña: $PASSWORD"
    echo ""
    echo "Ejecuta en MySQL:"
    echo "CREATE USER '$USUARIO'@'localhost' IDENTIFIED BY '$PASSWORD';"
    echo "GRANT ALL PRIVILEGES ON $DATABASE.* TO '$USUARIO'@'localhost';"
    echo "FLUSH PRIVILEGES;"
}

# ===========================================
# 2. CREAR USUARIO DE SISTEMA LINUX
# ===========================================

crear_usuario_sistema() {
    echo "=== Crear Usuario de Sistema ==="
    
    USUARIO="webmaster"
    PASSWORD=$(sh generar_password.sh -l 16 -a | grep -oP '\x1b\[0;32m\K[^\x1b]*' | head -1)
    
    echo "Creando usuario: $USUARIO"
    sudo useradd -m -s /bin/bash "$USUARIO"
    echo "$USUARIO:$PASSWORD" | sudo chpasswd
    
    echo ""
    echo "Usuario creado exitosamente:"
    echo "Usuario: $USUARIO"
    echo "Contraseña: $PASSWORD"
    echo ""
    echo "Guarda esta información de forma segura!"
}

# ===========================================
# 3. CONFIGURAR POSTGRESQL
# ===========================================

crear_usuario_postgresql() {
    echo "=== Crear Usuario PostgreSQL ==="
    
    PASSWORD=$(sh generar_password.sh -l 20 -a | grep -oP '\x1b\[0;32m\K[^\x1b]*' | head -1)
    USUARIO="app_user"
    DATABASE="app_db"
    
    echo "Usuario: $USUARIO"
    echo "Base de datos: $DATABASE"
    echo "Contraseña: $PASSWORD"
    echo ""
    echo "Ejecuta en PostgreSQL:"
    echo "CREATE USER $USUARIO WITH PASSWORD '$PASSWORD';"
    echo "CREATE DATABASE $DATABASE OWNER $USUARIO;"
    echo "GRANT ALL PRIVILEGES ON DATABASE $DATABASE TO $USUARIO;"
}

# ===========================================
# 4. GENERAR ARCHIVO .ENV PARA APLICACIÓN
# ===========================================

generar_archivo_env() {
    echo "=== Generar archivo .env ==="
    
    DB_PASS=$(sh generar_password.sh -l 20 -a | grep -oP '\x1b\[0;32m\K[^\x1b]*' | head -1)
    JWT_SECRET=$(sh generar_password.sh -l 32 -c | grep -oP '\x1b\[0;32m\K[^\x1b]*' | head -1)
    APP_KEY=$(sh generar_password.sh -l 32 -c | grep -oP '\x1b\[0;32m\K[^\x1b]*' | head -1)
    
    cat > .env << EOF
# Configuración de Base de Datos
DB_HOST=localhost
DB_PORT=5432
DB_NAME=mi_app
DB_USER=app_user
DB_PASSWORD=$DB_PASS

# Seguridad
JWT_SECRET=$JWT_SECRET
APP_KEY=$APP_KEY

# Aplicación
APP_NAME=MiAplicacion
APP_ENV=production
APP_DEBUG=false
EOF
    
    chmod 600 .env
    echo "Archivo .env creado con contraseñas seguras"
    echo "Permisos establecidos a 600 (solo lectura del propietario)"
}

# ===========================================
# 5. GENERAR MÚLTIPLES CONTRASEÑAS PARA SERVIDORES
# ===========================================

generar_inventario_passwords() {
    echo "=== Generar Inventario de Contraseñas ==="
    
    ARCHIVO="passwords_servidores_$(date +%Y%m%d).txt"
    
    {
        echo "========================================="
        echo "CONTRASEÑAS DE SERVIDORES"
        echo "Generado: $(date)"
        echo "========================================="
        echo ""
        
        echo "SERVIDOR WEB (Apache/Nginx):"
        sh generar_password.sh -l 16 -c | grep -A5 "Generando"
        echo ""
        
        echo "BASE DE DATOS (MySQL/PostgreSQL):"
        sh generar_password.sh -l 20 -c | grep -A5 "Generando"
        echo ""
        
        echo "PANEL DE ADMINISTRACIÓN:"
        sh generar_password.sh -l 24 -c | grep -A5 "Generando"
        echo ""
        
        echo "API KEY:"
        sh generar_password.sh -l 32 -c | grep -A5 "Generando"
        echo ""
        
        echo "========================================="
        echo "IMPORTANTE: Guarda este archivo de forma segura"
        echo "y elimínalo después de transferir las contraseñas"
        echo "========================================="
    } > "$ARCHIVO"
    
    chmod 600 "$ARCHIVO"
    echo "Inventario creado: $ARCHIVO"
    echo "Permisos: 600 (solo propietario)"
}

# ===========================================
# 6. CONFIGURAR SSH CON PASSPHRASE
# ===========================================

generar_ssh_key_con_passphrase() {
    echo "=== Generar SSH Key con Passphrase Segura ==="
    
    EMAIL="admin@miservidor.com"
    PASSPHRASE=$(sh generar_password.sh -l 24 -c | grep -oP '\x1b\[0;32m\K[^\x1b]*' | head -1)
    
    echo "Generando clave SSH..."
    echo "Email: $EMAIL"
    echo "Passphrase: $PASSPHRASE"
    echo ""
    echo "Ejecuta:"
    echo "ssh-keygen -t ed25519 -C '$EMAIL' -f ~/.ssh/id_ed25519_servidor"
    echo ""
    echo "Cuando pida passphrase, usa: $PASSPHRASE"
    echo ""
    echo "¡GUARDA LA PASSPHRASE DE FORMA SEGURA!"
}

# ===========================================
# 7. CONFIGURAR WORDPRESS
# ===========================================

configurar_wordpress() {
    echo "=== Generar Configuración WordPress ==="
    
    DB_PASSWORD=$(sh generar_password.sh -l 20 -a | grep -oP '\x1b\[0;32m\K[^\x1b]*' | head -1)
    AUTH_KEY=$(sh generar_password.sh -l 64 -c | grep -oP '\x1b\[0;32m\K[^\x1b]*' | head -1)
    SECURE_AUTH_KEY=$(sh generar_password.sh -l 64 -c | grep -oP '\x1b\[0;32m\K[^\x1b]*' | head -1)
    LOGGED_IN_KEY=$(sh generar_password.sh -l 64 -c | grep -oP '\x1b\[0;32m\K[^\x1b]*' | head -1)
    NONCE_KEY=$(sh generar_password.sh -l 64 -c | grep -oP '\x1b\[0;32m\K[^\x1b]*' | head -1)
    
    echo "Configuración para wp-config.php:"
    echo ""
    echo "define('DB_PASSWORD', '$DB_PASSWORD');"
    echo ""
    echo "define('AUTH_KEY',         '$AUTH_KEY');"
    echo "define('SECURE_AUTH_KEY',  '$SECURE_AUTH_KEY');"
    echo "define('LOGGED_IN_KEY',    '$LOGGED_IN_KEY');"
    echo "define('NONCE_KEY',        '$NONCE_KEY');"
}

# ===========================================
# 8. ROTAR CONTRASEÑAS (Backup antiguas)
# ===========================================

rotar_contraseña() {
    echo "=== Rotar Contraseña con Backup ==="
    
    SERVICIO="mysql_root"
    FECHA=$(date +%Y%m%d_%H%M%S)
    NUEVA_PASSWORD=$(sh generar_password.sh -l 20 -c | grep -oP '\x1b\[0;32m\K[^\x1b]*' | head -1)
    
    # Crear directorio de backups si no existe
    mkdir -p ~/.password_backups
    chmod 700 ~/.password_backups
    
    # Guardar nueva contraseña
    echo "$FECHA - $SERVICIO: $NUEVA_PASSWORD" >> ~/.password_backups/password_history.txt
    chmod 600 ~/.password_backups/password_history.txt
    
    echo "Servicio: $SERVICIO"
    echo "Nueva contraseña: $NUEVA_PASSWORD"
    echo "Backup guardado en: ~/.password_backups/password_history.txt"
    echo ""
    echo "IMPORTANTE: Actualiza la contraseña en el servicio y guárdala en tu gestor de contraseñas"
}

# ===========================================
# MENÚ PRINCIPAL
# ===========================================

mostrar_menu() {
    echo ""
    echo "========================================="
    echo "EJEMPLOS DE USO - GENERADOR DE CONTRASEÑAS"
    echo "========================================="
    echo ""
    echo "1. Crear usuario MySQL"
    echo "2. Crear usuario de sistema Linux"
    echo "3. Crear usuario PostgreSQL"
    echo "4. Generar archivo .env"
    echo "5. Generar inventario de contraseñas"
    echo "6. Generar SSH key con passphrase"
    echo "7. Configurar WordPress"
    echo "8. Rotar contraseña con backup"
    echo "0. Salir"
    echo ""
    echo -n "Selecciona una opción: "
}

# Ejecución principal
if [ "$1" = "" ]; then
    mostrar_menu
    read opcion
    
    case $opcion in
        1) crear_usuario_mysql ;;
        2) crear_usuario_sistema ;;
        3) crear_usuario_postgresql ;;
        4) generar_archivo_env ;;
        5) generar_inventario_passwords ;;
        6) generar_ssh_key_con_passphrase ;;
        7) configurar_wordpress ;;
        8) rotar_contraseña ;;
        0) echo "Saliendo..." ;;
        *) echo "Opción inválida" ;;
    esac
else
    # Permitir ejecutar funciones directamente
    case $1 in
        mysql) crear_usuario_mysql ;;
        sistema) crear_usuario_sistema ;;
        postgresql) crear_usuario_postgresql ;;
        env) generar_archivo_env ;;
        inventario) generar_inventario_passwords ;;
        ssh) generar_ssh_key_con_passphrase ;;
        wordpress) configurar_wordpress ;;
        rotar) rotar_contraseña ;;
        *) echo "Opción inválida. Usa: mysql, sistema, postgresql, env, inventario, ssh, wordpress, rotar" ;;
    esac
fi
