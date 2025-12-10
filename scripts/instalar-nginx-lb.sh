#!/bin/bash
# Script para instalar y configurar Nginx como balanceador de carga
# Uso: ./instalar-nginx-lb.sh <ip_backend_1> <ip_backend_2> [ip_backend_3] ...

set -e

if [ $# -lt 2 ]; then
    echo "Uso: $0 <ip_backend_1> <ip_backend_2> [ip_backend_3] ..."
    echo "Ejemplo: $0 192.168.100.10 192.168.100.11"
    exit 1
fi

echo "=== Instalando Nginx como Balanceador de Carga ==="
echo "Backend servers: $@"
echo ""

# Actualizar sistema
echo "1. Actualizando sistema..."
sudo apt update
sudo apt upgrade -y

# Instalar Nginx
echo "2. Instalando Nginx..."
sudo apt install nginx -y

# Hacer backup de configuración
echo "3. Haciendo backup de configuración..."
sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup

# Generar lista de servidores backend
SERVER_LIST=""
for IP in "$@"; do
    SERVER_LIST="${SERVER_LIST}        server ${IP}:80 weight=1 max_fails=3 fail_timeout=30s;\n"
done

# Crear configuración
echo "4. Generando configuración..."
sudo tee /etc/nginx/nginx.conf > /dev/null <<EOF
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 768;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log;

    gzip on;

    upstream backend_pool {
        $(echo -e "$SERVER_LIST")
    }

    server {
        listen 80 default_server;
        listen [::]:80 default_server;
        
        server_name _;

        access_log /var/log/nginx/loadbalancer-access.log main;
        error_log /var/log/nginx/loadbalancer-error.log;

        client_max_body_size 10M;

        location / {
            proxy_pass http://backend_pool;
            
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            
            proxy_connect_timeout 60s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
            
            proxy_buffering on;
            proxy_buffer_size 4k;
            proxy_buffers 8 4k;
        }

        location /nginx_status {
            stub_status on;
            access_log off;
            allow 127.0.0.1;
            allow 192.168.100.0/24;
            deny all;
        }
    }
}
EOF

# Verificar configuración
echo "5. Verificando configuración..."
if sudo nginx -t; then
    echo "✅ Configuración válida"
else
    echo "❌ Error en la configuración"
    exit 1
fi

# Configurar firewall
echo "6. Configurando firewall..."
sudo ufw allow 80/tcp

# Habilitar y reiniciar Nginx
echo "7. Iniciando Nginx..."
sudo systemctl enable nginx
sudo systemctl restart nginx

# Verificar estado
echo ""
echo "=== Verificación ==="
if sudo systemctl is-active --quiet nginx; then
    echo "✅ Nginx está corriendo"
else
    echo "❌ Error: Nginx no está corriendo"
    sudo journalctl -u nginx -n 20
    exit 1
fi

# Probar respuesta HTTP
sleep 2
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost)
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Nginx responde correctamente (HTTP $HTTP_CODE)"
else
    echo "⚠️  Nginx responde con código HTTP $HTTP_CODE"
fi

echo ""
echo "=== Instalación completada ==="
echo "Estadísticas: http://<IP_BALANCER>/nginx_status"

