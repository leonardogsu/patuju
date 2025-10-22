<?php
/**
 * Configuración de WordPress para Docker
 * 
 * Copiar este archivo como wp-config.php en cada directorio de sitio
 * y ajustar los valores según corresponda
 */

// ** Configuración de MySQL - Obtener valores de .env ** //

/** Nombre de la base de datos (cambiar para cada sitio) */
define('DB_NAME', 'wp_sitio1');  // wp_sitio2, wp_sitio3, etc.

/** Usuario de la base de datos */
define('DB_USER', 'wpuser');

/** Contraseña de la base de datos (usar la del archivo .env) */
define('DB_PASSWORD', 'tu_password_del_archivo_env');

/** Servidor de base de datos (nombre del contenedor Docker) */
define('DB_HOST', 'mysql');

/** Charset de la base de datos */
define('DB_CHARSET', 'utf8mb4');

/** Cotejamiento de la base de datos */
define('DB_COLLATE', 'utf8mb4_unicode_ci');

/**#@+
 * Claves únicas de autenticación y salado.
 *
 * Define cada clave con una frase aleatoria distinta.
 * Puedes generarlas usando el {@link https://api.wordpress.org/secret-key/1.1/salt/ servicio de claves secretas de WordPress}
 * Puedes cambiar las claves en cualquier momento para invalidar todas las cookies existentes.
 *
 * @since 2.6.0
 */
define('AUTH_KEY',         'pon aquí tu clave única de frase');
define('SECURE_AUTH_KEY',  'pon aquí tu clave única de frase');
define('LOGGED_IN_KEY',    'pon aquí tu clave única de frase');
define('NONCE_KEY',        'pon aquí tu clave única de frase');
define('AUTH_SALT',        'pon aquí tu clave única de frase');
define('SECURE_AUTH_SALT', 'pon aquí tu clave única de frase');
define('LOGGED_IN_SALT',   'pon aquí tu clave única de frase');
define('NONCE_SALT',       'pon aquí tu clave única de frase');

/**#@-*/

/**
 * Prefijo de la base de datos de WordPress.
 *
 * Puedes tener múltiples instalaciones en una misma base de datos si les das a cada una un prefijo único.
 */
$table_prefix = 'wp_';

/**
 * Para desarrolladores: modo de depuración de WordPress.
 *
 * Cambia esto a true para activar la notificación de errores durante el desarrollo.
 * Se recomienda encarecidamente a los desarrolladores de plugins y temas que usen WP_DEBUG
 * en sus entornos de desarrollo.
 */
define('WP_DEBUG', false);

/**
 * Configuración adicional recomendada para Docker/producción
 */

// Forzar HTTPS (descomenta si usas SSL)
// define('FORCE_SSL_ADMIN', true);
// if (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
//     $_SERVER['HTTPS'] = 'on';
// }

// Aumentar memoria si es necesario
// define('WP_MEMORY_LIMIT', '256M');

// Desactivar edición de archivos desde el panel
define('DISALLOW_FILE_EDIT', true);

// Límite de revisiones de posts
define('WP_POST_REVISIONS', 5);

// Vaciar papelera automáticamente (días)
define('EMPTY_TRASH_DAYS', 30);

// Reparación de base de datos (activar solo cuando sea necesario)
// define('WP_ALLOW_REPAIR', true);

/* ¡Eso es todo, detén de editar! Feliz blogging. */

/** Ruta absoluta al directorio de WordPress. */
if ( !defined('ABSPATH') )
    define('ABSPATH', dirname(__FILE__) . '/');

/** Configura las variables de WordPress y los archivos incluidos. */
require_once(ABSPATH . 'wp-settings.php');
