#!/usr/bin/env python3
"""
Script para concatenar TODOS los archivos de un directorio
y sus subdirectorios de forma recursiva, agregando separadores
con la ruta relativa de cada archivo.
"""

import os
import sys
import argparse
from pathlib import Path


def concatenar_todos_archivos(directorio_raiz, archivo_salida='concatenado.txt', exclusiones=None, verificar=True):
    """
    Concatena TODOS los archivos del directorio y subdirectorios recursivamente.

    Args:
        directorio_raiz: Ruta del directorio raíz a procesar
        archivo_salida: Nombre del archivo de salida
        exclusiones: Lista de carpetas/archivos a excluir
        verificar: Si True, ejecuta verificación automática al finalizar
    """
    directorio_raiz = Path(directorio_raiz).resolve()

    if not directorio_raiz.exists():
        print(f"❌ Error: El directorio '{directorio_raiz}' no existe.")
        return False

    if not directorio_raiz.is_dir():
        print(f"❌ Error: '{directorio_raiz}' no es un directorio.")
        return False

    # Exclusiones por defecto
    if exclusiones is None:
        exclusiones = {
            'node_modules', '.git', '__pycache__', '.venv', 'venv',
            '.idea', '.vscode', 'dist', 'build', '.next', '.cache',
            'vendor', 'bower_components'
        }
    else:
        exclusiones = set(exclusiones)

    # Agregar el archivo de salida a las exclusiones
    exclusiones.add(archivo_salida)

    archivos_encontrados = []
    archivos_procesados = []
    archivos_con_error = []
    archivos_grandes = []
    directorios_excluidos = 0

    # Recorrer recursivamente el directorio
    print(f"🔍 Buscando TODOS los archivos en: {directorio_raiz}")
    print(f"📋 Excluyendo carpetas: {', '.join(sorted(exclusiones))}\n")

    for ruta_actual, directorios, archivos in os.walk(directorio_raiz):
        # Filtrar directorios a excluir (modifica la lista in-place)
        directorios[:] = [d for d in directorios if d not in exclusiones]

        # Contar directorios excluidos
        directorios_antes = len(directorios) + len([d for d in os.listdir(ruta_actual)
                                                    if os.path.isdir(os.path.join(ruta_actual, d)) and d in exclusiones])
        directorios_excluidos += directorios_antes - len(directorios)

        for archivo in archivos:
            # Excluir el archivo de salida si está en el mismo directorio
            if archivo not in exclusiones:
                ruta_completa = Path(ruta_actual) / archivo
                archivos_encontrados.append(ruta_completa)

    if not archivos_encontrados:
        print("⚠️  No se encontraron archivos en el directorio.")
        return False

    print(f"📁 Se encontraron {len(archivos_encontrados)} archivo(s)")
    if directorios_excluidos > 0:
        print(f"🚫 Se excluyeron {directorios_excluidos} carpeta(s)\n")

    # Crear archivo de salida
    ruta_salida = directorio_raiz / archivo_salida

    try:
        with open(ruta_salida, 'w', encoding='utf-8', errors='ignore') as salida:
            # Escribir encabezado
            encabezado = f"""{'=' * 80}
CONCATENACIÓN DE ARCHIVOS
{'=' * 80}
Directorio raíz: {directorio_raiz}
Total de archivos: {len(archivos_encontrados)}
Fecha: {Path(__file__).stat().st_mtime if Path(__file__).exists() else 'N/A'}
{'=' * 80}

"""
            salida.write(encabezado)

            for idx, archivo_path in enumerate(sorted(archivos_encontrados), 1):
                # Obtener ruta relativa desde la raíz
                ruta_relativa = archivo_path.relative_to(directorio_raiz)

                # Mostrar progreso
                porcentaje = (idx / len(archivos_encontrados)) * 100
                print(f"  [{porcentaje:5.1f}%] Procesando ({idx}/{len(archivos_encontrados)}): {ruta_relativa}")

                # Escribir separador con información completa
                separador = f"\n{'=' * 80}\n"
                separador += f"📄 ARCHIVO {idx}/{len(archivos_encontrados)}\n"
                separador += f"{'=' * 80}\n"
                separador += f"Ruta relativa: {ruta_relativa}\n"
                separador += f"Path completo:  {archivo_path}\n"
                separador += f"{'=' * 80}\n\n"

                salida.write(separador)

                # Intentar leer y escribir el contenido del archivo
                try:
                    # Verificar el tamaño del archivo
                    tamaño = archivo_path.stat().st_size

                    # Si el archivo es binario o muy grande, informar
                    if tamaño > 10 * 1024 * 1024:  # Mayor a 10MB
                        mensaje = f"[ARCHIVO GRANDE: {tamaño / (1024*1024):.2f} MB - No incluido en concatenación]\n\n"
                        salida.write(mensaje)
                        archivos_grandes.append(archivo_path)
                    else:
                        with open(archivo_path, 'r', encoding='utf-8', errors='ignore') as f:
                            contenido = f.read()
                            salida.write(contenido)
                            salida.write("\n\n")
                        archivos_procesados.append(archivo_path)
                except Exception as e:
                    mensaje_error = f"[ERROR: No se pudo leer el archivo - {str(e)}]\n\n"
                    salida.write(mensaje_error)
                    archivos_con_error.append((archivo_path, str(e)))

        print(f"\n{'=' * 80}")
        print(f"✅ Concatenación completada")
        print(f"{'=' * 80}")
        print(f"📄 Archivo de salida: {ruta_salida}")
        print(f"📊 Tamaño del archivo: {ruta_salida.stat().st_size / 1024:.2f} KB")
        print(f"\n📈 ESTADÍSTICAS:")
        print(f"   Total archivos encontrados: {len(archivos_encontrados)}")
        print(f"   ✓ Procesados correctamente:  {len(archivos_procesados)}")
        if archivos_grandes:
            print(f"   ⚠ Archivos grandes omitidos: {len(archivos_grandes)}")
        if archivos_con_error:
            print(f"   ✗ Archivos con error:        {len(archivos_con_error)}")
        print(f"{'=' * 80}")

        # Ejecutar verificación automática
        if verificar:
            print("\n🔍 Ejecutando verificación automática...")
            verificar_concatenacion(
                archivos_encontrados,
                archivos_procesados,
                archivos_con_error,
                archivos_grandes,
                ruta_salida
            )

        return True

    except Exception as e:
        print(f"❌ Error al crear el archivo de salida: {str(e)}")
        return False


def verificar_concatenacion(archivos_encontrados, archivos_procesados, archivos_con_error, archivos_grandes, ruta_salida):
    """
    Verifica que la concatenación se haya realizado correctamente.

    Args:
        archivos_encontrados: Lista de todos los archivos encontrados
        archivos_procesados: Lista de archivos procesados correctamente
        archivos_con_error: Lista de tuplas (archivo, error)
        archivos_grandes: Lista de archivos omitidos por tamaño
        ruta_salida: Ruta del archivo de salida
    """
    print(f"\n{'=' * 80}")
    print("🔍 VERIFICACIÓN DE CONCATENACIÓN")
    print(f"{'=' * 80}")

    total_encontrados = len(archivos_encontrados)
    total_procesados = len(archivos_procesados)
    total_grandes = len(archivos_grandes)
    total_errores = len(archivos_con_error)

    # Calcular porcentaje de éxito
    total_intentados = total_procesados + total_errores + total_grandes
    porcentaje_exito = (total_procesados / total_encontrados * 100) if total_encontrados > 0 else 0

    print(f"\n📊 Resumen:")
    print(f"   Archivos encontrados:        {total_encontrados}")
    print(f"   Procesados exitosamente:     {total_procesados} ({porcentaje_exito:.1f}%)")
    print(f"   Omitidos por tamaño (>10MB): {total_grandes}")
    print(f"   Con errores de lectura:      {total_errores}")

    # Verificar integridad
    if total_intentados == total_encontrados:
        print(f"\n✅ VERIFICACIÓN EXITOSA: Todos los archivos fueron procesados")
    else:
        print(f"\n⚠️  ADVERTENCIA: Diferencia de {total_encontrados - total_intentados} archivo(s)")

    # Mostrar detalles de archivos grandes
    if archivos_grandes:
        print(f"\n📦 Archivos omitidos por tamaño:")
        for archivo in archivos_grandes[:10]:  # Mostrar solo los primeros 10
            ruta_rel = archivo.relative_to(ruta_salida.parent)
            tamaño_mb = archivo.stat().st_size / (1024 * 1024)
            print(f"   • {ruta_rel} ({tamaño_mb:.2f} MB)")
        if len(archivos_grandes) > 10:
            print(f"   ... y {len(archivos_grandes) - 10} más")

    # Mostrar detalles de errores
    if archivos_con_error:
        print(f"\n❌ Archivos con errores de lectura:")
        for archivo, error in archivos_con_error[:10]:  # Mostrar solo los primeros 10
            ruta_rel = archivo.relative_to(ruta_salida.parent)
            print(f"   • {ruta_rel}")
            print(f"     Error: {error}")
        if len(archivos_con_error) > 10:
            print(f"   ... y {len(archivos_con_error) - 10} más")

    # Verificar que el archivo de salida existe y tiene contenido
    if ruta_salida.exists():
        tamaño_kb = ruta_salida.stat().st_size / 1024
        if tamaño_kb > 0:
            print(f"\n✓ Archivo de salida creado correctamente: {tamaño_kb:.2f} KB")
        else:
            print(f"\n⚠️  ADVERTENCIA: El archivo de salida está vacío")
    else:
        print(f"\n❌ ERROR: El archivo de salida no se creó correctamente")

    # Resumen final
    print(f"\n{'=' * 80}")
    if total_errores == 0 and total_intentados == total_encontrados:
        print("✅ RESULTADO: Concatenación 100% exitosa")
    elif total_errores == 0:
        print("✅ RESULTADO: Concatenación exitosa (algunos archivos omitidos por tamaño)")
    else:
        print("⚠️  RESULTADO: Concatenación completada con algunos errores")
    print(f"{'=' * 80}\n")


def main():
    """Función principal del script."""
    # Configurar argumentos de línea de comandos
    parser = argparse.ArgumentParser(
        description='Concatena TODOS los archivos de un directorio y subdirectorios de forma recursiva.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Ejemplos de uso:
  python concatenar_archivos.py
  python concatenar_archivos.py -d /ruta/personalizada
  python concatenar_archivos.py -d C:\\Users\\Usuario\\MiCarpeta -o resultado.txt
  python concatenar_archivos.py -d /mi/proyecto --sin-exclusiones
        """
    )

    parser.add_argument(
        '-d', '--directorio',
        type=str,
        default=r'E:\git\wordpress-multisite',
        help='Directorio a procesar (por defecto: E:\\git\\wordpress-multisite)'
    )

    parser.add_argument(
        '-o', '--output',
        type=str,
        default='concatenado.txt',
        help='Nombre del archivo de salida (por defecto: concatenado.txt)'
    )

    parser.add_argument(
        '-i', '--interactivo',
        action='store_true',
        help='Modo interactivo para seleccionar el directorio'
    )

    parser.add_argument(
        '--sin-exclusiones',
        action='store_true',
        help='No excluir ninguna carpeta (incluye node_modules, .git, etc.)'
    )

    parser.add_argument(
        '-e', '--excluir',
        nargs='+',
        help='Carpetas adicionales a excluir (ej: -e temp cache logs)'
    )

    parser.add_argument(
        '--no-verificar',
        action='store_true',
        help='Desactivar la verificación automática al finalizar'
    )

    args = parser.parse_args()

    # Determinar exclusiones
    exclusiones = None
    if args.sin_exclusiones:
        exclusiones = set()
        exclusiones.add(args.output)  # Siempre excluir el archivo de salida
    elif args.excluir:
        # Exclusiones por defecto + las especificadas por el usuario
        exclusiones = {
            'node_modules', '.git', '__pycache__', '.venv', 'venv',
            '.idea', '.vscode', 'dist', 'build', '.next', '.cache',
            'vendor', 'bower_components'
        }
        exclusiones.update(args.excluir)

    # Modo interactivo
    if args.interactivo or (len(sys.argv) == 1 and not os.path.exists(args.directorio)):
        print("=" * 80)
        print("CONCATENADOR DE ARCHIVOS")
        print("=" * 80)
        print(f"\nDirectorio por defecto: {args.directorio}")

        respuesta = input("\n¿Desea usar el directorio por defecto? (s/n): ").strip().lower()

        if respuesta == 'n' or respuesta == 'no':
            directorio_custom = input("Ingrese la ruta del directorio: ").strip()
            if directorio_custom:
                args.directorio = directorio_custom

        nombre_salida = input(f"Nombre del archivo de salida [{args.output}]: ").strip()
        if nombre_salida:
            args.output = nombre_salida

        print()

    # Ejecutar la concatenación
    concatenar_todos_archivos(
        args.directorio,
        args.output,
        exclusiones,
        verificar=not args.no_verificar
    )


if __name__ == '__main__':
    main()