#!/bin/sh
#
# Script para generar contraseñas seguras
# Uso: ./generar_password.sh [opciones]
#

# Colores para output (opcional)
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # Sin color

# Función para mostrar ayuda
mostrar_ayuda() {
    echo "${BLUE}==================================================${NC}"
    echo "${GREEN}  Generador de Contraseñas Seguras${NC}"
    echo "${BLUE}==================================================${NC}"
    echo ""
    echo "Uso: $0 [opciones]"
    echo ""
    echo "Opciones:"
    echo "  -l, --longitud NUM    Longitud de la contraseña (por defecto: 16)"
    echo "  -n, --numero NUM      Número de contraseñas a generar (por defecto: 1)"
    echo "  -s, --simple          Contraseña simple (solo letras y números)"
    echo "  -c, --compleja        Contraseña compleja (letras, números y símbolos)"
    echo "  -m, --memorable       Contraseña memorable (palabras + números)"
    echo "  -a, --alfanumerica    Solo letras y números (sin símbolos)"
    echo "  -h, --help            Mostrar esta ayuda"
    echo ""
    echo "Ejemplos:"
    echo "  $0                    # Genera 1 contraseña de 16 caracteres"
    echo "  $0 -l 24 -n 5         # Genera 5 contraseñas de 24 caracteres"
    echo "  $0 -c -l 32           # Genera contraseña compleja de 32 caracteres"
    echo "  $0 -m                 # Genera contraseña memorable"
    echo ""
}

# Función para generar contraseña con /dev/urandom
generar_password_urandom() {
    longitud=$1
    tipo=$2
    
    case $tipo in
        "simple")
            # Solo letras y números
            tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$longitud"
            ;;
        "compleja")
            # Letras, números y símbolos especiales
            tr -dc 'A-Za-z0-9!@#$%^&*()_+-=[]{}|;:,.<>?' < /dev/urandom | head -c "$longitud"
            ;;
        "alfanumerica")
            # Solo alfanuméricos
            tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$longitud"
            ;;
        *)
            # Por defecto: letras, números y algunos símbolos seguros
            tr -dc 'A-Za-z0-9!@#$%^&*-_=+' < /dev/urandom | head -c "$longitud"
            ;;
    esac
    echo ""
}

# Función para generar contraseña con openssl (alternativa)
generar_password_openssl() {
    longitud=$1
    openssl rand -base64 "$((longitud * 2))" | tr -dc 'A-Za-z0-9!@#$%^&*-_=+' | head -c "$longitud"
    echo ""
}

# Función para generar contraseña memorable
generar_password_memorable() {
    # Lista de palabras comunes (puedes expandir esta lista)
    palabras="tigre leon agua fuego tierra viento rayo nube estrella luna sol mar monte rio valle bosque campo flor arbol piedra"
    
    palabra1=$(echo "$palabras" | tr ' ' '\n' | shuf -n 1)
    palabra2=$(echo "$palabras" | tr ' ' '\n' | shuf -n 1)
    numero=$(tr -dc '0-9' < /dev/urandom | head -c 3)
    simbolo=$(tr -dc '!@#$%^&*-_=+' < /dev/urandom | head -c 1)
    
    # Capitalizar primera letra
    palabra1_cap=$(echo "$palabra1" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')
    palabra2_cap=$(echo "$palabra2" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')
    
    echo "${palabra1_cap}${simbolo}${palabra2_cap}${numero}"
}

# Función para verificar fortaleza de contraseña
verificar_fortaleza() {
    password=$1
    longitud=${#password}
    
    echo "${YELLOW}Análisis de fortaleza:${NC}"
    echo "  Longitud: $longitud caracteres"
    
    # Verificar tipos de caracteres
    tiene_minus=$(echo "$password" | grep -q '[a-z]' && echo "✓" || echo "✗")
    tiene_mayus=$(echo "$password" | grep -q '[A-Z]' && echo "✓" || echo "✗")
    tiene_nums=$(echo "$password" | grep -q '[0-9]' && echo "✓" || echo "✗")
    tiene_simb=$(echo "$password" | grep -q '[^A-Za-z0-9]' && echo "✓" || echo "✗")
    
    echo "  Minúsculas: $tiene_minus"
    echo "  Mayúsculas: $tiene_mayus"
    echo "  Números: $tiene_nums"
    echo "  Símbolos: $tiene_simb"
    
    # Calcular entropía aproximada
    if [ "$longitud" -ge 16 ] && [ "$tiene_minus" = "✓" ] && [ "$tiene_mayus" = "✓" ] && [ "$tiene_nums" = "✓" ] && [ "$tiene_simb" = "✓" ]; then
        echo "  ${GREEN}Nivel: MUY FUERTE${NC}"
    elif [ "$longitud" -ge 12 ] && [ "$tiene_minus" = "✓" ] && [ "$tiene_mayus" = "✓" ] && [ "$tiene_nums" = "✓" ]; then
        echo "  ${GREEN}Nivel: FUERTE${NC}"
    elif [ "$longitud" -ge 8 ]; then
        echo "  ${YELLOW}Nivel: MEDIA${NC}"
    else
        echo "  ${YELLOW}Nivel: DÉBIL (aumenta la longitud)${NC}"
    fi
}

# Valores por defecto
LONGITUD=16
NUMERO=1
TIPO="default"
VERIFICAR=0

# Procesar argumentos
while [ $# -gt 0 ]; do
    case $1 in
        -l|--longitud)
            LONGITUD=$2
            shift 2
            ;;
        -n|--numero)
            NUMERO=$2
            shift 2
            ;;
        -s|--simple)
            TIPO="simple"
            shift
            ;;
        -c|--compleja)
            TIPO="compleja"
            shift
            ;;
        -m|--memorable)
            TIPO="memorable"
            shift
            ;;
        -a|--alfanumerica)
            TIPO="alfanumerica"
            shift
            ;;
        -v|--verificar)
            VERIFICAR=1
            shift
            ;;
        -h|--help)
            mostrar_ayuda
            exit 0
            ;;
        *)
            echo "Opción desconocida: $1"
            echo "Usa -h o --help para ver la ayuda"
            exit 1
            ;;
    esac
done

# Validar longitud
if [ "$LONGITUD" -lt 8 ]; then
    echo "${YELLOW}Advertencia: Se recomienda una longitud mínima de 8 caracteres${NC}"
    echo "Ajustando a 8 caracteres..."
    LONGITUD=8
fi

# Generar contraseñas
echo "${BLUE}==================================================${NC}"
echo "${GREEN}Generando $NUMERO contraseña(s)...${NC}"
echo "${BLUE}==================================================${NC}"
echo ""

for i in $(seq 1 "$NUMERO"); do
    if [ "$NUMERO" -gt 1 ]; then
        echo "${YELLOW}Contraseña #$i:${NC}"
    fi
    
    if [ "$TIPO" = "memorable" ]; then
        PASSWORD=$(generar_password_memorable)
    else
        # Intentar con /dev/urandom primero
        if [ -r /dev/urandom ]; then
            PASSWORD=$(generar_password_urandom "$LONGITUD" "$TIPO")
        # Si no está disponible, usar openssl
        elif command -v openssl > /dev/null 2>&1; then
            PASSWORD=$(generar_password_openssl "$LONGITUD")
        else
            echo "Error: No se encontró /dev/urandom ni openssl"
            exit 1
        fi
    fi
    
    echo "  ${GREEN}$PASSWORD${NC}"
    
    # Verificar fortaleza si se solicita
    if [ "$VERIFICAR" -eq 1 ] || [ "$NUMERO" -eq 1 ]; then
        echo ""
        verificar_fortaleza "$PASSWORD"
    fi
    
    echo ""
done

echo "${BLUE}==================================================${NC}"
echo "${YELLOW}Consejo: Guarda estas contraseñas en un gestor seguro${NC}"
echo "${BLUE}==================================================${NC}"
