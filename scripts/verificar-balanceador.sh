#!/bin/bash
# Script completo de verificación del balanceador de carga
# Uso: ./verificar-balanceador.sh [tipo] [url]
# tipo: haproxy o nginx (auto-detecta si no se especifica)

URL=${2:-http://localhost}
TIPO=${1:-auto}

echo "=== Verificación Completa del Balanceador de Carga ==="
echo ""

# Detectar tipo de balanceador
if [ "$TIPO" = "auto" ]; then
    if systemctl is-active --quiet haproxy 2>/dev/null; then
        TIPO="haproxy"
        echo "✅ Detectado: HAProxy"
    elif systemctl is-active --quiet nginx 2>/dev/null; then
        TIPO="nginx"
        echo "✅ Detectado: Nginx"
    else
        echo "❌ Error: No se detectó ningún balanceador activo"
        exit 1
    fi
fi

echo "URL: $URL"
echo "Tipo: $TIPO"
echo ""

# 1. Verificar que el servicio está corriendo
echo "1. Verificando estado del servicio..."
if [ "$TIPO" = "haproxy" ]; then
    if systemctl is-active --quiet haproxy; then
        echo "   ✅ HAProxy está corriendo"
    else
        echo "   ❌ HAProxy no está corriendo"
        exit 1
    fi
else
    if systemctl is-active --quiet nginx; then
        echo "   ✅ Nginx está corriendo"
    else
        echo "   ❌ Nginx no está corriendo"
        exit 1
    fi
fi

# 2. Verificar respuesta HTTP
echo ""
echo "2. Verificando respuesta HTTP..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$URL")
if [ "$HTTP_CODE" = "200" ]; then
    echo "   ✅ Servidor responde correctamente (HTTP $HTTP_CODE)"
else
    echo "   ❌ Error: Servidor responde con código HTTP $HTTP_CODE"
    exit 1
fi

# 3. Verificar balanceo
echo ""
echo "3. Verificando balanceo de carga..."
echo "   Realizando 10 peticiones..."
declare -A servidores
for i in {1..10}; do
    response=$(curl -s "$URL" 2>/dev/null)
    if echo "$response" | grep -q "Backend Server 1"; then
        servidores["Backend Server 1"]=$((${servidores["Backend Server 1"]:-0} + 1))
    elif echo "$response" | grep -q "Backend Server 2"; then
        servidores["Backend Server 2"]=$((${servidores["Backend Server 2"]:-0} + 1))
    fi
done

if [ ${#servidores[@]} -gt 1 ]; then
    echo "   ✅ Balanceo funcionando: tráfico distribuido"
    for servidor in "${!servidores[@]}"; do
        echo "      - $servidor: ${servidores[$servidor]} peticiones"
    done
else
    echo "   ⚠️  Advertencia: solo se detectó un servidor"
fi

# 4. Verificar estadísticas (si están disponibles)
echo ""
echo "4. Verificando estadísticas..."
if [ "$TIPO" = "haproxy" ]; then
    STATS_CODE=$(curl -s -o /dev/null -w "%{http_code}" -u admin:admin123 http://localhost:8404/stats 2>/dev/null)
    if [ "$STATS_CODE" = "200" ]; then
        echo "   ✅ Panel de estadísticas accesible (puerto 8404)"
    else
        echo "   ⚠️  Panel de estadísticas no accesible"
    fi
else
    STATS_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/nginx_status 2>/dev/null)
    if [ "$STATS_CODE" = "200" ]; then
        echo "   ✅ Estadísticas accesibles (/nginx_status)"
    else
        echo "   ⚠️  Estadísticas no accesibles"
    fi
fi

# 5. Verificar logs
echo ""
echo "5. Verificando logs..."
if [ "$TIPO" = "haproxy" ]; then
    if [ -f /var/log/haproxy.log ]; then
        LOG_LINES=$(sudo tail -n 10 /var/log/haproxy.log 2>/dev/null | wc -l)
        if [ "$LOG_LINES" -gt 0 ]; then
            echo "   ✅ Logs de HAProxy disponibles ($LOG_LINES líneas recientes)"
        else
            echo "   ⚠️  Logs de HAProxy vacíos o no accesibles"
        fi
    else
        echo "   ⚠️  Archivo de logs no encontrado"
    fi
else
    if [ -f /var/log/nginx/loadbalancer-access.log ]; then
        LOG_LINES=$(sudo tail -n 10 /var/log/nginx/loadbalancer-access.log 2>/dev/null | wc -l)
        if [ "$LOG_LINES" -gt 0 ]; then
            echo "   ✅ Logs de Nginx disponibles ($LOG_LINES líneas recientes)"
        else
            echo "   ⚠️  Logs de Nginx vacíos o no accesibles"
        fi
    else
        echo "   ⚠️  Archivo de logs no encontrado"
    fi
fi

# 6. Verificar conectividad con backends
echo ""
echo "6. Verificando conectividad con servidores backend..."
# Intentar detectar IPs de backend desde la configuración
if [ "$TIPO" = "haproxy" ]; then
    BACKEND_IPS=$(sudo grep -E "server.*192\.168\." /etc/haproxy/haproxy.cfg | grep -oE "192\.168\.[0-9]+\.[0-9]+" | sort -u)
else
    BACKEND_IPS=$(sudo grep -E "server.*192\.168\." /etc/nginx/nginx.conf | grep -oE "192\.168\.[0-9]+\.[0-9]+" | sort -u)
fi

if [ -n "$BACKEND_IPS" ]; then
    for IP in $BACKEND_IPS; do
        if ping -c 1 -W 2 "$IP" > /dev/null 2>&1; then
            HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$IP" 2>/dev/null)
            if [ "$HTTP_CODE" = "200" ]; then
                echo "   ✅ $IP: accesible (HTTP $HTTP_CODE)"
            else
                echo "   ⚠️  $IP: accesible pero responde con HTTP $HTTP_CODE"
            fi
        else
            echo "   ❌ $IP: no accesible"
        fi
    done
else
    echo "   ⚠️  No se pudieron detectar IPs de backend desde la configuración"
fi

echo ""
echo "=== Verificación completada ==="

