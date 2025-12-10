#!/bin/bash
# Script para probar failover (alta disponibilidad)
# Uso: ./test-failover.sh <ip_backend_1> <ip_backend_2> [url_balanceador]

if [ $# -lt 2 ]; then
    echo "Uso: $0 <ip_backend_1> <ip_backend_2> [url_balanceador]"
    echo "Ejemplo: $0 192.168.100.10 192.168.100.11 http://localhost"
    exit 1
fi

BACKEND1=$1
BACKEND2=$2
URL=${3:-http://localhost}

echo "=== Prueba de Failover ==="
echo "Backend 1: $BACKEND1"
echo "Backend 2: $BACKEND2"
echo "Balanceador: $URL"
echo ""

# Función para verificar qué servidor responde
verificar_servidor() {
    response=$(curl -s "$URL" 2>/dev/null)
    if echo "$response" | grep -q "Backend Server 1"; then
        echo "Backend 1"
    elif echo "$response" | grep -q "Backend Server 2"; then
        echo "Backend 2"
    else
        echo "Desconocido"
    fi
}

# 1. Estado inicial
echo "1. Estado inicial (ambos servidores activos)..."
for i in {1..5}; do
    servidor=$(verificar_servidor)
    echo "   Petición $i: $servidor"
    sleep 1
done

# 2. Detener backend 1
echo ""
echo "2. Deteniendo Backend 1 ($BACKEND1)..."
ssh -o StrictHostKeyChecking=no ubuntu@"$BACKEND1" "sudo systemctl stop apache2" 2>/dev/null || \
ssh -o StrictHostKeyChecking=no ubuntu@"$BACKEND1" "sudo systemctl stop nginx" 2>/dev/null

echo "   Esperando 5 segundos para que el balanceador detecte el fallo..."
sleep 5

echo "   Verificando que solo Backend 2 responde..."
for i in {1..5}; do
    servidor=$(verificar_servidor)
    echo "   Petición $i: $servidor"
    if [ "$servidor" != "Backend 2" ] && [ "$servidor" != "Desconocido" ]; then
        echo "   ⚠️  Advertencia: Backend 1 aún está recibiendo tráfico"
    fi
    sleep 1
done

# 3. Reactivar backend 1
echo ""
echo "3. Reactivando Backend 1 ($BACKEND1)..."
ssh -o StrictHostKeyChecking=no ubuntu@"$BACKEND1" "sudo systemctl start apache2" 2>/dev/null || \
ssh -o StrictHostKeyChecking=no ubuntu@"$BACKEND1" "sudo systemctl start nginx" 2>/dev/null

echo "   Esperando 10 segundos para que el balanceador reintegre el servidor..."
sleep 10

echo "   Verificando que ambos servidores responden..."
for i in {1..10}; do
    servidor=$(verificar_servidor)
    echo "   Petición $i: $servidor"
    sleep 1
done

echo ""
echo "=== Prueba de failover completada ==="

