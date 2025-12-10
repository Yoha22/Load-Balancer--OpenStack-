# Guía 3: Configuración de HAProxy como Balanceador de Carga

Esta guía te ayudará a instalar y configurar HAProxy para balancear el tráfico entre tus servidores web backend.

## Prerrequisitos

- Instancia del balanceador creada en OpenStack
- Acceso SSH a la instancia del balanceador
- Servidores backend configurados y funcionando (ver Guía 2)
- IPs de los servidores backend (ej: `192.168.100.10`, `192.168.100.11`)

## Paso 1: Conectarse a la Instancia del Balanceador

```bash
ssh -i <TU_KEY_FILE> ubuntu@<IP_FLOTANTE_BALANCER>
```

## Paso 2: Actualizar el Sistema

```bash
sudo apt update
sudo apt upgrade -y
```

## Paso 3: Instalar HAProxy

```bash
sudo apt install haproxy -y
```

Verificar la instalación:

```bash
haproxy -v
```

## Paso 4: Verificar IPs de los Backend Servers

Antes de configurar, necesitas conocer las IPs privadas de tus servidores backend:

```bash
# Desde el balanceador, prueba conectividad
ping -c 3 192.168.100.10  # IP de web-backend-1
ping -c 3 192.168.100.11  # IP de web-backend-2

# Verifica que respondan HTTP
curl http://192.168.100.10
curl http://192.168.100.11
```

Anota las IPs que funcionan correctamente.

## Paso 5: Configurar HAProxy

### 5.1 Hacer Backup de la Configuración Original

```bash
sudo cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.backup
```

### 5.2 Editar el Archivo de Configuración

```bash
sudo nano /etc/haproxy/haproxy.cfg
```

### 5.3 Configuración Completa de HAProxy

Reemplaza el contenido del archivo con la siguiente configuración. **Ajusta las IPs según tus servidores backend:**

```haproxy
global
    log /dev/log    local0
    log /dev/log    local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

    # Default SSL material locations
    ca-base /etc/ssl/certs
    crt-base /etc/ssl/private

    # See: https://ssl-config.mozilla.org/#server=haproxy&server-version=2.0.3&config=intermediate
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

# Frontend: Punto de entrada para el tráfico
frontend http_frontend
    bind *:80
    mode http
    default_backend http_backend

    # Opcional: Redirigir a HTTPS (descomentar si configuras SSL)
    # redirect scheme https code 301 if !{ ssl_fc }

# Backend: Pool de servidores web
backend http_backend
    mode http
    balance roundrobin
    
    # Health check
    option httpchk GET /
    http-check expect status 200
    
    # Servidor backend 1
    server web-backend-1 192.168.100.10:80 check inter 2000 rise 2 fall 3
    
    # Servidor backend 2
    server web-backend-2 192.168.100.11:80 check inter 2000 rise 2 fall 3
    
    # Si tienes más servidores, agrégalos aquí:
    # server web-backend-3 192.168.100.12:80 check inter 2000 rise 2 fall 3

# Estadísticas de HAProxy (opcional pero recomendado)
frontend stats
    bind *:8404
    stats enable
    stats uri /stats
    stats refresh 30s
    stats admin if TRUE
    stats auth admin:admin123  # Cambia la contraseña
```

### 5.4 Explicación de la Configuración

- **global**: Configuración global de HAProxy (logs, usuario, daemon)
- **defaults**: Valores por defecto para todos los frontends y backends
- **frontend http_frontend**: Escucha en el puerto 80 y redirige al backend
- **backend http_backend**: Define el pool de servidores
  - `balance roundrobin`: Algoritmo de balanceo (round-robin)
  - `option httpchk GET /`: Health check HTTP
  - `server`: Define cada servidor backend
    - `check`: Habilita health checks
    - `inter 2000`: Intervalo de verificación (2 segundos)
    - `rise 2`: Intentos exitosos para considerar el servidor UP
    - `fall 3`: Intentos fallidos para considerar el servidor DOWN
- **frontend stats**: Panel de estadísticas en el puerto 8404

### 5.5 Algoritmos de Balanceo Alternativos

Puedes cambiar `balance roundrobin` por otros algoritmos:

- **roundrobin**: Distribución rotativa (por defecto)
- **leastconn**: Envía a el servidor con menos conexiones
- **source**: Mantiene la misma sesión según IP de origen
- **uri**: Balanceo según URI
- **hdr**: Balanceo según header HTTP

Ejemplo con `leastconn`:

```haproxy
backend http_backend
    mode http
    balance leastconn
    # ... resto de la configuración
```

## Paso 6: Verificar la Configuración

Antes de reiniciar, verifica que la configuración sea válida:

```bash
sudo haproxy -f /etc/haproxy/haproxy.cfg -c
```

Deberías ver: `Configuration file is valid`

## Paso 7: Habilitar y Iniciar HAProxy

```bash
# Habilitar HAProxy para que inicie al arrancar
sudo systemctl enable haproxy

# Iniciar HAProxy
sudo systemctl start haproxy

# Verificar estado
sudo systemctl status haproxy
```

## Paso 8: Configurar Firewall

```bash
# Permitir puerto 80 (HTTP)
sudo ufw allow 80/tcp

# Permitir puerto 8404 (estadísticas, opcional)
sudo ufw allow 8404/tcp

# Verificar
sudo ufw status
```

## Paso 9: Verificar que HAProxy Funciona

### 9.1 Verificar desde la Misma Instancia

```bash
# Probar que HAProxy responde
curl http://localhost

# Ver estadísticas
curl http://localhost:8404/stats
```

### 9.2 Verificar desde tu Máquina Local

Abre tu navegador y accede a:

```
http://<IP_FLOTANTE_BALANCER>
```

Deberías ver alternarse las páginas de los diferentes servidores backend al refrescar.

### 9.3 Verificar Panel de Estadísticas

Accede al panel de estadísticas:

```
http://<IP_FLOTANTE_BALANCER>:8404/stats
```

Usuario: `admin`
Contraseña: `admin123` (cambia esto en producción)

## Paso 10: Probar el Balanceo

### 10.1 Script de Prueba Simple

Crea un script para probar el balanceo:

```bash
nano test-balanceo.sh
```

Contenido:

```bash
#!/bin/bash

echo "Probando balanceo de carga..."
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
chmod +x test-balanceo.sh
./test-balanceo.sh
```

Deberías ver que las peticiones se distribuyen entre los servidores.

## Paso 11: Configurar Logs (Opcional pero Recomendado)

### 11.1 Configurar rsyslog para HAProxy

```bash
sudo nano /etc/rsyslog.d/49-haproxy.conf
```

Agrega:

```
$ModLoad imudp
$UDPServerRun 514
$UDPServerAddress 127.0.0.1
local0.*    /var/log/haproxy.log
& stop
```

Reinicia rsyslog:

```bash
sudo systemctl restart rsyslog
```

### 11.2 Ver Logs

```bash
sudo tail -f /var/log/haproxy.log
```

## Paso 12: Configuración Avanzada (Opcional)

### 12.1 Sticky Sessions (Persistencia de Sesión)

Si necesitas que un usuario siempre vaya al mismo servidor:

```haproxy
backend http_backend
    mode http
    balance roundrobin
    cookie SERVERID insert indirect nocache
    
    server web-backend-1 192.168.100.10:80 check cookie s1
    server web-backend-2 192.168.100.11:80 check cookie s2
```

### 12.2 Configurar HTTPS (SSL/TLS)

Si quieres agregar soporte HTTPS:

```haproxy
frontend https_frontend
    bind *:443 ssl crt /etc/ssl/certs/certificado.pem
    mode http
    default_backend http_backend
```

### 12.3 Agregar Más Servidores Backend

Simplemente agrega más líneas `server` en el backend:

```haproxy
server web-backend-3 192.168.100.12:80 check inter 2000 rise 2 fall 3
```

Luego recarga HAProxy:

```bash
sudo systemctl reload haproxy
```

## Resumen de Configuración

Al finalizar esta guía, deberías tener:

- ✅ HAProxy instalado y funcionando
- ✅ Configuración básica de balanceo round-robin
- ✅ Health checks configurados
- ✅ Panel de estadísticas accesible
- ✅ Balanceo funcionando entre servidores backend
- ✅ Logs configurados (opcional)

## Comandos Útiles

```bash
# Ver estado de HAProxy
sudo systemctl status haproxy

# Reiniciar HAProxy
sudo systemctl restart haproxy

# Recargar configuración sin interrumpir conexiones
sudo systemctl reload haproxy

# Verificar configuración
sudo haproxy -f /etc/haproxy/haproxy.cfg -c

# Ver logs en tiempo real
sudo tail -f /var/log/haproxy.log

# Ver estadísticas desde línea de comandos
echo "show stat" | sudo socat stdio /run/haproxy/admin.sock
```

## Siguiente Paso

Una vez que HAProxy esté funcionando correctamente, puedes:
- Probar el balanceo (ver Guía 5: Pruebas y Verificación)
- Configurar Nginx como alternativa (ver Guía 4)
- Implementar configuraciones avanzadas según tus necesidades

## Troubleshooting

### Problema: HAProxy no inicia
- **Solución**: 
  - Verifica la configuración: `sudo haproxy -f /etc/haproxy/haproxy.cfg -c`
  - Revisa los logs: `sudo journalctl -u haproxy -n 50`
  - Verifica que el puerto 80 no esté en uso: `sudo netstat -tulpn | grep :80`

### Problema: No puedo acceder desde el navegador
- **Solución**: 
  - Verifica el firewall: `sudo ufw status`
  - Verifica que HAProxy esté corriendo: `sudo systemctl status haproxy`
  - Verifica los grupos de seguridad en OpenStack (puerto 80)
  - Prueba desde la misma instancia: `curl http://localhost`

### Problema: Todos los servidores aparecen como DOWN
- **Solución**: 
  - Verifica conectividad: `ping 192.168.100.10`
  - Verifica que los backend respondan: `curl http://192.168.100.10`
  - Verifica los grupos de seguridad (deben permitir tráfico interno)
  - Revisa los logs: `sudo tail -f /var/log/haproxy.log`

### Problema: El balanceo no funciona
- **Solución**: 
  - Verifica que ambos servidores estén UP en las estadísticas
  - Verifica la configuración del algoritmo de balanceo
  - Prueba con múltiples peticiones: `for i in {1..20}; do curl -s http://localhost | grep "Backend"; done`

### Problema: No puedo acceder al panel de estadísticas
- **Solución**: 
  - Verifica que el puerto 8404 esté abierto en el firewall
  - Verifica que el frontend stats esté configurado correctamente
  - Prueba desde la misma instancia: `curl http://localhost:8404/stats`

