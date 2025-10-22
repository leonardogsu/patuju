-- Script de inicialización para crear las 10 bases de datos WordPress

-- Crear bases de datos
CREATE DATABASE IF NOT EXISTS wp_sitio1 CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS wp_sitio2 CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS wp_sitio3 CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS wp_sitio4 CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS wp_sitio5 CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS wp_sitio6 CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS wp_sitio7 CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS wp_sitio8 CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS wp_sitio9 CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS wp_sitio10 CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Otorgar privilegios al usuario wpuser sobre todas las bases de datos
GRANT ALL PRIVILEGES ON wp_sitio1.* TO 'wpuser'@'%';
GRANT ALL PRIVILEGES ON wp_sitio2.* TO 'wpuser'@'%';
GRANT ALL PRIVILEGES ON wp_sitio3.* TO 'wpuser'@'%';
GRANT ALL PRIVILEGES ON wp_sitio4.* TO 'wpuser'@'%';
GRANT ALL PRIVILEGES ON wp_sitio5.* TO 'wpuser'@'%';
GRANT ALL PRIVILEGES ON wp_sitio6.* TO 'wpuser'@'%';
GRANT ALL PRIVILEGES ON wp_sitio7.* TO 'wpuser'@'%';
GRANT ALL PRIVILEGES ON wp_sitio8.* TO 'wpuser'@'%';
GRANT ALL PRIVILEGES ON wp_sitio9.* TO 'wpuser'@'%';
GRANT ALL PRIVILEGES ON wp_sitio10.* TO 'wpuser'@'%';

-- Aplicar cambios
FLUSH PRIVILEGES;

-- Crear usuario adicional de solo lectura para backups (opcional)
CREATE USER IF NOT EXISTS 'backup_user'@'%' IDENTIFIED BY 'backup_password_cambiar';
GRANT SELECT, LOCK TABLES, SHOW VIEW ON *.* TO 'backup_user'@'%';
FLUSH PRIVILEGES;
