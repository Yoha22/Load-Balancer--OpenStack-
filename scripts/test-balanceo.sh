#!/bin/bash
# Script para probar el balanceo de carga
# Uso: ./test-balanceo.sh [numero_peticiones] [url]

NUM_PETICIONES=${1:-20}
URL=${2:-http://localhost}

echo "=== Prueba de Balanceo de Carga ==="
echo "URL: $URL"
echo "Peticiones: $NUM_PETICIONES"
echo ""

# Contadores
declare -A contadores

echo "Realizando peticiones..."
for i in $(seq 1 $NUM_PETICIONES); do
    response=$(curl -s "$URL" 2>/dev/null)
    
    # Detectar qué servidor respondió
    if echo "$response" | grep -q "Backend Server 1"; then
        servidor="Backend Server 1"
        contadores["Backend Server 1"]=$((${contadores["Backend Server 1"]:-0} + 1))
    elif echo "$response" | grep -q "Backend Server 2"; then
        servidor="Backend Server 2"
        contadores["Backend Server 2"]=$((${contadores["Backend Server 2"]:-0} + 1))
    elif echo "$response" | grep -q "Backend Server 3"; then
        servidor="Backend Server 3"
        contadores["Backend Server 3"]=$((${contadores["Backend Server 3"]:-0} + 1))
    else
        servidor="Desconocido"
        contadores["Desconocido"]=$((${contadores["Desconocido"]:-0} + 1))
    fi
    
    printf "Petición %3d: %s\r" $i "$servidor"
    sleep 0.1
done

echo ""
echo ""
echo "=== Resultados ==="
echo ""

for servidor in "${!contadores[@]}"; do
    count=${contadores[$servidor]}
    porcentaje=$((count * 100 / NUM_PETICIONES))
    printf "%-20s: %3d peticiones (%3d%%)\n" "$servidor" $count $porcentaje
done

echo ""
echo "Total: $NUM_PETICIONES peticiones"

# Verificar distribución
if [ ${#contadores[@]} -gt 1 ]; then
    echo ""
    echo "✅ Balanceo funcionando: tráfico distribuido entre múltiples servidores"
else
    echo ""
    echo "⚠️  Advertencia: todo el tráfico va a un solo servidor"
fi

