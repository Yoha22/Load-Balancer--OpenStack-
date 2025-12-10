#!/bin/bash
# Script para instalar y configurar HAProxy
# Uso: ./instalar-haproxy.sh <ip_backend_1> <ip_backend_2> [ip_backend_3] ...

set -e

if [ $# -lt 2 ]; then
    echo "Uso: $0 <ip_backend_1> <ip_backend_2> [ip_backend_3] ..."
    echo "Ejemplo: $0 192.168.100.10 192.168.100.11"
    exit 1
fi

echo "=== Instalando HAProxy ==="
echo "Backend servers: $@"
echo ""

# Actualizar sistema
echo "1. Actualizando sistema..."
sudo apt update
sudo apt upgrade -y

# Instalar HAProxy
echo "2. Instalando HAProxy..."
sudo apt install haproxy -y

# Hacer backup de configuración
echo "3. Haciendo backup de configuración..."
sudo cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.backup

# Generar configuración
echo "4. Generando configuración..."

# Construir lista de servidores backend
SERVER_LIST=""
SERVER_NUM=1
for IP in "$@"; do
    SERVER_LIST="${SERVER_LIST}    server web-backend-${SERVER_NUM} ${IP}:80 check inter 2000 rise 2 fall 3\n"
    SERVER_NUM=$((SERVER_NUM + 1))
done

# Crear configuración
sudo tee /etc/haproxy/haproxy.cfg > /dev/null <<EOF
global
    log /dev/log    local0
    log /dev/log    local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

    ca-base /etc/ssl/certs
    crt-base /etc/ssl/private

    ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
    ssl-default-bind-options ssl-min-ver TLSv1.2 no-tls-tickets

defaults
    log     global
    mode    http
    option  httplog
    option  dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000
    errorfile 400 /etc/haproxy/errors/400.http
    errorfile 403 /etc/haproxy/errors/403.http
    errorfile 408 /etc/haproxy/errors/408.http
    errorfile 500 /etc/haproxy/errors/500.http
    errorfile 502 /etc/haproxy/errors/502.http
    errorfile 503 /etc/haproxy/errors/503.http
    errorfile 504 /etc/haproxy/errors/504.http

frontend http_frontend
    bind *:80
    mode http
    default_backend http_backend

backend http_backend
    mode http
    balance roundrobin
    option httpchk GET /
    http-check expect status 200
$(echo -e "$SERVER_LIST")
frontend stats
    bind *:8404
    stats enable
    stats uri /stats
    stats refresh 30s
    stats admin if TRUE
    stats auth admin:admin123
EOF

# Verificar configuración
echo "5. Verificando configuración..."
if sudo haproxy -f /etc/haproxy/haproxy.cfg -c; then
    echo "✅ Configuración válida"
else
    echo "❌ Error en la configuración"
    exit 1
fi

# Configurar firewall
echo "6. Configurando firewall..."
sudo ufw allow 80/tcp
sudo ufw allow 8404/tcp

# Habilitar y reiniciar HAProxy
echo "7. Iniciando HAProxy..."
sudo systemctl enable haproxy
sudo systemctl restart haproxy

# Verificar estado
echo ""
echo "=== Verificación ==="
if sudo systemctl is-active --quiet haproxy; then
    echo "✅ HAProxy está corriendo"
else
    echo "❌ Error: HAProxy no está corriendo"
    sudo journalctl -u haproxy -n 20
    exit 1
fi

# Probar respuesta HTTP
sleep 2
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost)
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ HAProxy responde correctamente (HTTP $HTTP_CODE)"
else
    echo "⚠️  HAProxy responde con código HTTP $HTTP_CODE"
fi

echo ""
echo "=== Instalación completada ==="
echo "Panel de estadísticas: http://<IP_BALANCER>:8404/stats"
echo "Usuario: admin"
echo "Contraseña: admin123"

