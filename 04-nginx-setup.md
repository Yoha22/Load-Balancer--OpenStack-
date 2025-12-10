# Guía 4: Configuración de Nginx como Balanceador de Carga

Esta guía te ayudará a instalar y configurar Nginx como balanceador de carga para distribuir el tráfico entre tus servidores web backend.

## Prerrequisitos

- Instancia del balanceador creada en OpenStack
- Acceso SSH a la instancia del balanceador
- Servidores backend configurados y funcionando (ver Guía 2)
- IPs de los servidores backend (ej: `192.168.100.10`, `192.168.100.11`)

**Nota**: Si ya tienes HAProxy funcionando en el puerto 80, puedes:
- Usar Nginx en un puerto diferente (ej: 8080) para comparar
- Detener HAProxy temporalmente
- Usar otra instancia para Nginx

## Paso 1: Conectarse a la Instancia del Balanceador

```bash
ssh -i <TU_KEY_FILE> ubuntu@<IP_FLOTANTE_BALANCER>
```

## Paso 2: Actualizar el Sistema

```bash
sudo apt update
sudo apt upgrade -y
```

## Paso 3: Instalar Nginx

```bash
sudo apt install nginx -y
```

Verificar la instalación:

```bash
nginx -v
```

## Paso 4: Verificar IPs de los Backend Servers

Antes de configurar, verifica que puedes acceder a los servidores backend:

```bash
# Probar conectividad
ping -c 3 192.168.100.10  # IP de web-backend-1
ping -c 3 192.168.100.11  # IP de web-backend-2

# Verificar que respondan HTTP
curl http://192.168.100.10
curl http://192.168.100.11
```

Anota las IPs que funcionan correctamente.

## Paso 5: Configurar Nginx como Balanceador

### 5.1 Hacer Backup de la Configuración Original

```bash
sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup
```

### 5.2 Editar el Archivo de Configuración Principal

```bash
sudo nano /etc/nginx/nginx.conf
```

### 5.3 Configuración Completa de Nginx

Reemplaza el contenido del archivo con la siguiente configuración. **Ajusta las IPs según tus servidores backend:**

```nginx
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 768;
    # multi_accept on;
}

http {
    ##
    # Basic Settings
    ##
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    # server_tokens off;

    # server_names_hash_bucket_size 64;
    # server_name_in_redirect off;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    ##
    # SSL Settings
    ##
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3; # Dropping SSLv3, ref: POODLE
    ssl_prefer_server_ciphers on;

    ##
    # Logging Settings
    ##
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log;

    ##
    # Gzip Settings
    ##
    gzip on;

    ##
    # Upstream: Pool de servidores backend
    ##
    upstream backend_pool {
        # Método de balanceo: round-robin (por defecto)
        # Otras opciones: least_conn, ip_hash
        
        # Health check básico (requiere módulo adicional para checks avanzados)
        server 192.168.100.10:80 weight=1 max_fails=3 fail_timeout=30s;
        server 192.168.100.11:80 weight=1 max_fails=3 fail_timeout=30s;
        
        # Si tienes más servidores, agrégalos aquí:
        # server 192.168.100.12:80 weight=1 max_fails=3 fail_timeout=30s;
        
        # Backup server (solo se usa si todos los demás están down)
        # server 192.168.100.13:80 backup;
    }

    ##
    # Servidor Virtual: Balanceador de Carga
    ##
    server {
        listen 80 default_server;
        listen [::]:80 default_server;
        
        server_name _;

        # Logs específicos para el balanceador
        access_log /var/log/nginx/loadbalancer-access.log main;
        error_log /var/log/nginx/loadbalancer-error.log;

        # Tamaño máximo del cuerpo de la petición
        client_max_body_size 10M;

        location / {
            # Proxy hacia el pool de servidores backend
            proxy_pass http://backend_pool;
            
            # Headers importantes para el proxy
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # Timeouts
            proxy_connect_timeout 60s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
            
            # Buffer settings
            proxy_buffering on;
            proxy_buffer_size 4k;
            proxy_buffers 8 4k;
        }

        # Página de estado/estadísticas (opcional)
        location /nginx_status {
            stub_status on;
            access_log off;
            allow 127.0.0.1;
            allow 192.168.100.0/24;  # Permitir desde la red interna
            deny all;
        }
    }
}
```

### 5.4 Explicación de la Configuración

- **upstream backend_pool**: Define el pool de servidores backend
  - `weight=1`: Peso del servidor (mayor peso = más tráfico)
  - `max_fails=3`: Intentos fallidos antes de marcar como down
  - `fail_timeout=30s`: Tiempo antes de reintentar un servidor marcado como down
- **server block**: Configura el servidor virtual que escucha en el puerto 80
- **proxy_pass**: Redirige el tráfico al pool de servidores
- **proxy_set_header**: Configura headers HTTP importantes para el proxy
- **location /nginx_status**: Endpoint para ver estadísticas de Nginx

### 5.5 Métodos de Balanceo Alternativos

Puedes cambiar el método de balanceo en el bloque `upstream`:

**Round-Robin (por defecto):**
```nginx
upstream backend_pool {
    # Distribución rotativa
    server 192.168.100.10:80;
    server 192.168.100.11:80;
}
```

**Least Connections:**
```nginx
upstream backend_pool {
    least_conn;  # Envía a el servidor con menos conexiones
    server 192.168.100.10:80;
    server 192.168.100.11:80;
}
```

**IP Hash (Sticky Sessions):**
```nginx
upstream backend_pool {
    ip_hash;  # Misma IP siempre va al mismo servidor
    server 192.168.100.10:80;
    server 192.168.100.11:80;
}
```

**Weighted Round-Robin:**
```nginx
upstream backend_pool {
    server 192.168.100.10:80 weight=3;  # Recibe 3 veces más tráfico
    server 192.168.100.11:80 weight=1;
}
```

## Paso 6: Verificar la Configuración

Antes de reiniciar, verifica que la configuración sea válida:

```bash
sudo nginx -t
```

Deberías ver: `nginx: configuration file /etc/nginx/nginx.conf test is successful`

## Paso 7: Habilitar y Reiniciar Nginx

```bash
# Habilitar Nginx para que inicie al arrancar
sudo systemctl enable nginx

# Reiniciar Nginx
sudo systemctl restart nginx

# Verificar estado
sudo systemctl status nginx
```

## Paso 8: Configurar Firewall

```bash
# Permitir puerto 80 (HTTP)
sudo ufw allow 80/tcp

# Verificar
sudo ufw status
```

## Paso 9: Verificar que Nginx Funciona

### 9.1 Verificar desde la Misma Instancia

```bash
# Probar que Nginx responde
curl http://localhost

# Ver estadísticas
curl http://localhost/nginx_status
```

### 9.2 Verificar desde tu Máquina Local

Abre tu navegador y accede a:

```
http://<IP_FLOTANTE_BALANCER>
```

Deberías ver alternarse las páginas de los diferentes servidores backend al refrescar.

### 9.3 Verificar Estadísticas de Nginx

Accede a las estadísticas:

```
http://<IP_FLOTANTE_BALANCER>/nginx_status
```

Verás información sobre conexiones activas, requests, etc.

## Paso 10: Probar el Balanceo

### 10.1 Script de Prueba Simple

Crea un script para probar el balanceo:

```bash
nano test-balanceo-nginx.sh
```

Contenido:

```bash
#!/bin/bash

echo "Probando balanceo de carga con Nginx..."
echo "Haciendo 10 peticiones al balanceador..."
echo ""

for i in {1..10}; do
    echo "Petición $i:"
    curl -s http://localhost | grep -o "Backend Server [0-9]" | head -1
    sleep 1
done

echo ""
echo "Prueba completada"
```

Hazlo ejecutable y ejecútalo:

```bash
chmod +x test-balanceo-nginx.sh
./test-balanceo-nginx.sh
```

Deberías ver que las peticiones se distribuyen entre los servidores.

## Paso 11: Configurar Health Checks Avanzados (Opcional)

Nginx no tiene health checks avanzados por defecto, pero puedes usar el módulo `nginx_upstream_check_module` o configurar health checks básicos.

### 11.1 Health Checks Básicos con max_fails

La configuración ya incluye `max_fails` y `fail_timeout` que proporcionan health checks básicos:

```nginx
server 192.168.100.10:80 weight=1 max_fails=3 fail_timeout=30s;
```

Esto marca el servidor como down después de 3 fallos consecutivos.

### 11.2 Verificar Estado de los Servidores

Puedes verificar qué servidores están activos revisando los logs:

```bash
sudo tail -f /var/log/nginx/loadbalancer-error.log
```

## Paso 12: Configuración Avanzada (Opcional)

### 12.1 Sticky Sessions con IP Hash

Si necesitas que un usuario siempre vaya al mismo servidor:

```nginx
upstream backend_pool {
    ip_hash;  # Basado en IP del cliente
    server 192.168.100.10:80;
    server 192.168.100.11:80;
}
```

### 12.2 Configurar HTTPS (SSL/TLS)

Si quieres agregar soporte HTTPS:

```nginx
server {
    listen 443 ssl http2;
    server_name _;

    ssl_certificate /etc/ssl/certs/certificado.crt;
    ssl_certificate_key /etc/ssl/private/certificado.key;

    location / {
        proxy_pass http://backend_pool;
        # ... resto de configuración proxy
    }
}
```

### 12.3 Agregar Más Servidores Backend

Simplemente agrega más líneas `server` en el bloque `upstream`:

```nginx
upstream backend_pool {
    server 192.168.100.10:80 weight=1 max_fails=3 fail_timeout=30s;
    server 192.168.100.11:80 weight=1 max_fails=3 fail_timeout=30s;
    server 192.168.100.12:80 weight=1 max_fails=3 fail_timeout=30s;
}
```

Luego recarga Nginx:

```bash
sudo systemctl reload nginx
```

### 12.4 Configurar Rate Limiting

Para limitar el número de peticiones:

```nginx
http {
    limit_req_zone $binary_remote_addr zone=limit:10m rate=10r/s;

    server {
        location / {
            limit_req zone=limit burst=20 nodelay;
            proxy_pass http://backend_pool;
            # ... resto de configuración
        }
    }
}
```

## Paso 13: Monitoreo y Logs

### 13.1 Ver Logs en Tiempo Real

```bash
# Logs de acceso
sudo tail -f /var/log/nginx/loadbalancer-access.log

# Logs de error
sudo tail -f /var/log/nginx/loadbalancer-error.log

# Todos los logs
sudo tail -f /var/log/nginx/*.log
```

### 13.2 Analizar Logs

```bash
# Ver las IPs más activas
sudo awk '{print $1}' /var/log/nginx/loadbalancer-access.log | sort | uniq -c | sort -rn | head -10

# Ver códigos de estado HTTP
sudo awk '{print $9}' /var/log/nginx/loadbalancer-access.log | sort | uniq -c | sort -rn
```

## Resumen de Configuración

Al finalizar esta guía, deberías tener:

- ✅ Nginx instalado y funcionando como balanceador
- ✅ Configuración básica de balanceo round-robin
- ✅ Health checks básicos configurados (max_fails)
- ✅ Endpoint de estadísticas accesible
- ✅ Balanceo funcionando entre servidores backend
- ✅ Logs configurados y accesibles

## Comandos Útiles

```bash
# Ver estado de Nginx
sudo systemctl status nginx

# Reiniciar Nginx
sudo systemctl restart nginx

# Recargar configuración sin interrumpir conexiones
sudo systemctl reload nginx

# Verificar configuración
sudo nginx -t

# Ver logs en tiempo real
sudo tail -f /var/log/nginx/loadbalancer-access.log

# Ver estadísticas
curl http://localhost/nginx_status

# Ver procesos de Nginx
ps aux | grep nginx
```

## Comparación: HAProxy vs Nginx

### HAProxy
- ✅ Especializado en balanceo de carga
- ✅ Health checks más avanzados
- ✅ Panel de estadísticas más completo
- ✅ Mejor para balanceo de carga puro

### Nginx
- ✅ También funciona como servidor web
- ✅ Más versátil (puede servir contenido estático)
- ✅ Configuración más simple para casos básicos
- ✅ Mejor si necesitas servir contenido además de balancear

## Siguiente Paso

Una vez que Nginx esté funcionando correctamente, puedes:
- Probar el balanceo (ver Guía 5: Pruebas y Verificación)
- Comparar el rendimiento con HAProxy
- Implementar configuraciones avanzadas según tus necesidades

## Troubleshooting

### Problema: Nginx no inicia
- **Solución**: 
  - Verifica la configuración: `sudo nginx -t`
  - Revisa los logs: `sudo journalctl -u nginx -n 50`
  - Verifica que el puerto 80 no esté en uso: `sudo netstat -tulpn | grep :80`

### Problema: No puedo acceder desde el navegador
- **Solución**: 
  - Verifica el firewall: `sudo ufw status`
  - Verifica que Nginx esté corriendo: `sudo systemctl status nginx`
  - Verifica los grupos de seguridad en OpenStack (puerto 80)
  - Prueba desde la misma instancia: `curl http://localhost`

### Problema: Error 502 Bad Gateway
- **Solución**: 
  - Verifica que los backend estén funcionando: `curl http://192.168.100.10`
  - Verifica conectividad: `ping 192.168.100.10`
  - Revisa los logs: `sudo tail -f /var/log/nginx/loadbalancer-error.log`
  - Verifica los grupos de seguridad (deben permitir tráfico interno)

### Problema: El balanceo no funciona
- **Solución**: 
  - Verifica que ambos servidores estén accesibles
  - Verifica la configuración del método de balanceo
  - Prueba con múltiples peticiones: `for i in {1..20}; do curl -s http://localhost | grep "Backend"; done`

### Problema: No puedo acceder a /nginx_status
- **Solución**: 
  - Verifica que la IP esté en la lista de `allow` en la configuración
  - Verifica que no haya un `deny all` bloqueando el acceso
  - Prueba desde la misma instancia: `curl http://localhost/nginx_status`

### Problema: Conflictos con HAProxy
- **Solución**: 
  - Si ambos están en la misma instancia, usa puertos diferentes
  - Detén uno de los servicios: `sudo systemctl stop haproxy` o `sudo systemctl stop nginx`
  - O usa instancias separadas para cada balanceador

