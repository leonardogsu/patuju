# Concatenador de Archivos (Recursivo)

Script en Python para concatenar **TODOS los archivos** de un directorio y sus subdirectorios de forma recursiva, con **verificación automática** de integridad.

## 📋 Características

- ✅ Busca recursivamente en todos los subdirectorios
- ✅ Concatena **TODOS los archivos** (no solo archivos ocultos)
- ✅ Agrega separadores con la ruta relativa y path completo de cada archivo
- ✅ **Verificación automática** de que todos los archivos se concatenaron correctamente
- ✅ Directorio por defecto: `E:\git\wordpress-multisite`
- ✅ Permite especificar directorio personalizado
- ✅ Excluye automáticamente carpetas comunes (`node_modules`, `.git`, `__pycache__`, etc.)
- ✅ Opción para incluir todo o personalizar exclusiones
- ✅ Modo interactivo y por línea de comandos
- ✅ Barra de progreso durante el procesamiento
- ✅ Manejo de archivos grandes y errores
- ✅ Estadísticas detalladas y reportes de verificación

## 🚀 Uso

### Modo 1: Usar directorio por defecto
```bash
python concatenar_archivos.py
```

### Modo 2: Especificar directorio personalizado
```bash
python concatenar_archivos.py -d "C:\mi\directorio"
```

### Modo 3: Personalizar nombre de salida
```bash
python concatenar_archivos.py -d "C:\mi\directorio" -o "todos_archivos.txt"
```

### Modo 4: Modo interactivo
```bash
python concatenar_archivos.py -i
```

### Modo 5: Sin exclusiones (incluye todo)
```bash
python concatenar_archivos.py -d "C:\mi\proyecto" --sin-exclusiones
```

### Modo 6: Excluir carpetas adicionales
```bash
python concatenar_archivos.py -d "C:\mi\proyecto" -e temp cache logs build
```

### Modo 7: Desactivar verificación automática
```bash
python concatenar_archivos.py -d "C:\mi\proyecto" --no-verificar
```

## 🔍 Verificación Automática

Por defecto, el script ejecuta una **verificación automática** al finalizar la concatenación. Esta verificación:

- ✓ Compara el número de archivos encontrados vs procesados
- ✓ Calcula el porcentaje de éxito
- ✓ Lista archivos omitidos por tamaño (>10MB)
- ✓ Muestra archivos con errores de lectura
- ✓ Verifica que el archivo de salida se creó correctamente
- ✓ Presenta un resumen detallado del proceso

### Ejemplo de salida de verificación:

```
================================================================================
🔍 VERIFICACIÓN DE CONCATENACIÓN
================================================================================

📊 Resumen:
   Archivos encontrados:        247
   Procesados exitosamente:     245 (99.2%)
   Omitidos por tamaño (>10MB): 1
   Con errores de lectura:      1

✅ VERIFICACIÓN EXITOSA: Todos los archivos fueron procesados

📦 Archivos omitidos por tamaño:
   • uploads/video-grande.mp4 (25.43 MB)

❌ Archivos con errores de lectura:
   • archivo-corrupto.dat
     Error: [Errno 13] Permission denied

✓ Archivo de salida creado correctamente: 2543.67 KB

================================================================================
✅ RESULTADO: Concatenación exitosa (algunos archivos omitidos por tamaño)
================================================================================
```

## 📝 Argumentos

- `-d`, `--directorio`: Ruta del directorio a procesar
- `-o`, `--output`: Nombre del archivo de salida (por defecto: `concatenado.txt`)
- `-i`, `--interactivo`: Modo interactivo para seleccionar opciones
- `--sin-exclusiones`: No excluir ninguna carpeta
- `-e`, `--excluir`: Carpetas adicionales a excluir (separadas por espacios)
- `--no-verificar`: Desactivar la verificación automática (activada por defecto)

## 🚫 Carpetas excluidas por defecto

El script excluye automáticamente estas carpetas comunes para evitar archivos innecesarios:

- `node_modules`
- `.git`
- `__pycache__`
- `.venv` / `venv`
- `.idea` / `.vscode`
- `dist` / `build`
- `.next` / `.cache`
- `vendor`
- `bower_components`

**Nota:** Puedes desactivar todas las exclusiones con `--sin-exclusiones` o agregar más con `-e`

## 📄 Formato de salida

El archivo generado tendrá el siguiente formato:

```
================================================================================
CONCATENACIÓN DE ARCHIVOS
================================================================================
Directorio raíz: E:\git\wordpress-multisite
Total de archivos: 247
================================================================================

================================================================================
📄 ARCHIVO 1/247
================================================================================
Ruta relativa: index.php
Path completo:  E:\git\wordpress-multisite\index.php
================================================================================

<?php
// Contenido del archivo
...


================================================================================
📄 ARCHIVO 2/247
================================================================================
Ruta relativa: wp-content\themes\mi-tema\style.css
Path completo:  E:\git\wordpress-multisite\wp-content\themes\mi-tema\style.css
================================================================================

/* Contenido del archivo */
...
```

Cada archivo incluye:
- **Número de archivo** (X/Total)
- **Ruta relativa** desde el directorio raíz
- **Path completo** del archivo en el sistema
- **Contenido** del archivo

## 🔍 Tipos de archivos procesados

El script procesa **TODOS** los archivos encontrados, incluyendo:

- Archivos PHP (`.php`)
- Archivos JavaScript (`.js`)
- Archivos CSS (`.css`)
- Archivos HTML (`.html`)
- Archivos de configuración (`.json`, `.yaml`, `.ini`, `.env`)
- Archivos ocultos (`.gitignore`, `.htaccess`)
- Archivos de texto (`.txt`, `.md`)
- Y cualquier otro tipo de archivo

## ⚙️ Requisitos

- Python 3.6 o superior
- Ninguna dependencia externa (usa solo librerías estándar)

## 💡 Notas importantes

- El archivo de salida se crea en el directorio raíz especificado
- Los archivos se procesan en orden alfabético
- **Archivos mayores a 10 MB** no se incluyen en la concatenación (solo se menciona su existencia)
- Si un archivo no puede leerse, se incluye un mensaje de error en su lugar
- Usa codificación UTF-8 con manejo de errores para evitar problemas con caracteres especiales
- El script muestra el progreso en tiempo real con porcentaje completado

## 📊 Información mostrada

Durante la ejecución, el script muestra:

- Total de archivos encontrados
- Carpetas excluidas
- Progreso en porcentaje y tiempo real
- Ruta de cada archivo procesado
- **Estadísticas de procesamiento:**
    - Archivos procesados correctamente
    - Archivos omitidos por tamaño
    - Archivos con errores
- Tamaño final del archivo concatenado
- **Verificación automática con:**
    - Porcentaje de éxito
    - Listado de archivos con problemas
    - Estado final de la operación

## 🎯 Casos de uso

- Preparar código para análisis con IA
- Crear backups de texto de proyectos completos
- Auditoría de código
- Documentación de proyectos
- Revisión de configuraciones
- Análisis de estructura de proyectos