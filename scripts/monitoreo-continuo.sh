#!/bin/bash
# Script de monitoreo continuo del balanceador de carga
# Uso: ./monitoreo-continuo.sh [url] [intervalo_segundos]

URL=${1:-http://localhost}
INTERVALO=${2:-5}

echo "=== Monitoreo Continuo del Balanceador ==="
echo "URL: $URL"
echo "Intervalo: $INTERVALO segundos"
echo "Presiona Ctrl+C para detener"
echo ""

# Función para obtener estadísticas
obtener_estadisticas() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Intentar obtener respuesta
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$URL" 2>/dev/null)
    
    if [ "$HTTP_CODE" = "200" ]; then
        # Obtener qué servidor respondió
        response=$(curl -s "$URL" 2>/dev/null)
        if echo "$response" | grep -q "Backend Server 1"; then
            SERVIDOR="Backend 1"
        elif echo "$response" | grep -q "Backend Server 2"; then
            SERVIDOR="Backend 2"
        elif echo "$response" | grep -q "Backend Server 3"; then
            SERVIDOR="Backend 3"
        else
            SERVIDOR="Desconocido"
        fi
        
        echo "[$timestamp] ✅ HTTP $HTTP_CODE | Servidor: $SERVIDOR"
    else
        echo "[$timestamp] ❌ HTTP $HTTP_CODE | Error en la respuesta"
    fi
}

# Capturar Ctrl+C
trap 'echo ""; echo "Monitoreo detenido"; exit 0' INT

# Bucle de monitoreo
while true; do
    obtener_estadisticas
    sleep "$INTERVALO"
done

