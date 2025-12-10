#!/bin/bash
# Script para instalar y configurar un servidor web backend
# Uso: ./instalar-backend.sh <numero_servidor> <ip_privada>

set -e

if [ $# -lt 2 ]; then
    echo "Uso: $0 <numero_servidor> <ip_privada>"
    echo "Ejemplo: $0 1 192.168.100.10"
    exit 1
fi

SERVER_NUM=$1
SERVER_IP=$2

echo "=== Instalando Backend Server $SERVER_NUM ==="
echo "IP: $SERVER_IP"
echo ""

# Actualizar sistema
echo "1. Actualizando sistema..."
sudo apt update
sudo apt upgrade -y

# Instalar Apache
echo "2. Instalando Apache..."
sudo apt install apache2 -y

# Configurar firewall
echo "3. Configurando firewall..."
sudo ufw allow 80/tcp
sudo ufw allow 22/tcp

# Crear página de prueba
echo "4. Creando página de prueba..."
sudo tee /var/www/html/index.html > /dev/null <<EOF
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Backend Server $SERVER_NUM</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .container {
            text-align: center;
            padding: 40px;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 10px;
            backdrop-filter: blur(10px);
        }
        h1 {
            font-size: 3em;
            margin: 0;
        }
        .server-info {
            margin-top: 20px;
            font-size: 1.2em;
        }
        .ip-address {
            background: rgba(255, 255, 255, 0.2);
            padding: 10px 20px;
            border-radius: 5px;
            display: inline-block;
            margin-top: 10px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Backend Server $SERVER_NUM</h1>
        <div class="server-info">
            <p><strong>Servidor:</strong> web-backend-$SERVER_NUM</p>
            <div class="ip-address">
                IP: $SERVER_IP
            </div>
            <p style="margin-top: 20px;">Este es el servidor backend número $SERVER_NUM</p>
            <p style="font-size: 0.9em; opacity: 0.8;">Sistema funcionando correctamente</p>
        </div>
    </div>
</body>
</html>
EOF

# Configurar permisos
echo "5. Configurando permisos..."
sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 755 /var/www/html

# Habilitar y reiniciar Apache
echo "6. Iniciando Apache..."
sudo systemctl enable apache2
sudo systemctl restart apache2

# Verificar estado
echo ""
echo "=== Verificación ==="
if sudo systemctl is-active --quiet apache2; then
    echo "✅ Apache está corriendo"
else
    echo "❌ Error: Apache no está corriendo"
    exit 1
fi

# Probar respuesta HTTP
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost)
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Servidor responde correctamente (HTTP $HTTP_CODE)"
else
    echo "❌ Error: Servidor no responde correctamente (HTTP $HTTP_CODE)"
    exit 1
fi

echo ""
echo "=== Instalación completada ==="
echo "Puedes probar el servidor con: curl http://$SERVER_IP"

