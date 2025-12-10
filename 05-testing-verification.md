# Guía 5: Pruebas y Verificación del Balanceador de Carga

Esta guía te ayudará a probar y verificar que tu balanceador de carga está funcionando correctamente, ya sea con HAProxy o Nginx.

## Prerrequisitos

- Balanceador de carga configurado (HAProxy o Nginx)
- Al menos 2 servidores backend funcionando
- Acceso SSH a la instancia del balanceador
- IP flotante del balanceador accesible desde tu máquina local

## Parte 1: Pruebas Básicas

### 1.1 Verificar que el Balanceador Responde

**Desde la instancia del balanceador:**

```bash
# Probar respuesta local
curl -I http://localhost

# Deberías ver algo como:
# HTTP/1.1 200 OK
```

**Desde tu máquina local:**

```bash
# Reemplaza con tu IP flotante
curl -I http://<IP_FLOTANTE_BALANCER>
```

### 1.2 Verificar que los Backend Están Accesibles

```bash
# Desde el balanceador, verifica cada backend
curl http://192.168.100.10
curl http://192.168.100.11

# Deberías ver el HTML de cada servidor
```

## Parte 2: Pruebas de Balanceo

### 2.1 Prueba Simple de Balanceo

**Script básico para probar balanceo:**

```bash
#!/bin/bash
# test-balanceo-basico.sh

echo "=== Prueba de Balanceo de Carga ==="
echo "Haciendo 20 peticiones..."
echo ""

for i in {1..20}; do
    response=$(curl -s http://localhost)
    server=$(echo "$response" | grep -o "Backend Server [0-9]" | head -1)
    echo "Petición $i: $server"
    sleep 0.5
done

echo ""
echo "Resumen:"
curl -s http://localhost | grep -o "Backend Server [0-9]" | sort | uniq -c
```

Guarda el script y ejecútalo:

```bash
chmod +x test-balanceo-basico.sh
./test-balanceo-basico.sh
```

**Resultado esperado:** Deberías ver que las peticiones se distribuyen entre los servidores.

### 2.2 Prueba con Estadísticas

**Para HAProxy:**

```bash
#!/bin/bash
# test-haproxy-stats.sh

echo "=== Estadísticas HAProxy ==="
echo ""

# Obtener estadísticas (requiere autenticación)
curl -u admin:admin123 http://localhost:8404/stats | grep "web-backend" | head -10
```

**Para Nginx:**

```bash
#!/bin/bash
# test-nginx-stats.sh

echo "=== Estadísticas Nginx ==="
echo ""

curl http://localhost/nginx_status
```

### 2.3 Prueba de Distribución de Carga

**Script avanzado que muestra la distribución:**

```bash
#!/bin/bash
# test-distribucion.sh

echo "=== Análisis de Distribución de Carga ==="
echo ""

# Contador para cada servidor
server1=0
server2=0
total=50

echo "Realizando $total peticiones..."
echo ""

for i in $(seq 1 $total); do
    response=$(curl -s http://localhost)
    if echo "$response" | grep -q "Backend Server 1"; then
        server1=$((server1 + 1))
        echo -n "1"
    elif echo "$response" | grep -q "Backend Server 2"; then
        server2=$((server2 + 1))
        echo -n "2"
    else
        echo -n "?"
    fi
    
    # Nueva línea cada 20 peticiones
    if [ $((i % 20)) -eq 0 ]; then
        echo ""
    fi
done

echo ""
echo ""
echo "=== Resultados ==="
echo "Backend Server 1: $server1 peticiones ($((server1 * 100 / total))%)"
echo "Backend Server 2: $server2 peticiones ($((server2 * 100 / total))%)"
echo "Total: $total peticiones"
```

## Parte 3: Pruebas de Health Checks

### 3.1 Verificar Health Checks en HAProxy

```bash
# Ver estado de los servidores en HAProxy
echo "show stat" | sudo socat stdio /run/haproxy/admin.sock | grep "web-backend"

# O desde el navegador:
# http://<IP_BALANCER>:8404/stats
```

**Interpretación:**
- `UP`: Servidor funcionando
- `DOWN`: Servidor no disponible
- `MAINT`: Servidor en mantenimiento

### 3.2 Simular Fallo de un Backend

**Paso 1: Detener un servidor backend**

```bash
# Conéctate a web-backend-1
ssh ubuntu@192.168.100.10

# Detener Apache
sudo systemctl stop apache2
# O si usas Nginx:
sudo systemctl stop nginx
```

**Paso 2: Verificar que el balanceador detecta el fallo**

```bash
# Desde el balanceador, verifica HAProxy stats
# O prueba múltiples peticiones - todas deberían ir al servidor activo
for i in {1..10}; do
    curl -s http://localhost | grep "Backend Server"
done
```

**Paso 3: Reactivar el servidor**

```bash
# En web-backend-1
sudo systemctl start apache2
```

**Paso 4: Verificar que se reintegra**

```bash
# Espera unos segundos y verifica que vuelve a recibir tráfico
for i in {1..10}; do
    curl -s http://localhost | grep "Backend Server"
done
```

### 3.3 Verificar Health Checks en Nginx

Nginx usa `max_fails` para detectar servidores caídos. Para verificar:

```bash
# Ver logs de error
sudo tail -f /var/log/nginx/loadbalancer-error.log

# Probar peticiones
for i in {1..20}; do
    curl -s http://localhost | grep "Backend Server"
done
```

## Parte 4: Pruebas de Rendimiento

### 4.1 Prueba de Carga Básica con Apache Bench

**Instalar Apache Bench:**

```bash
sudo apt install apache2-utils -y
```

**Ejecutar prueba de carga:**

```bash
# 100 peticiones, 10 concurrentes
ab -n 100 -c 10 http://<IP_BALANCER>/

# Resultados más detallados
ab -n 1000 -c 50 -v 2 http://<IP_BALANCER>/
```

**Interpretación de resultados:**
- **Requests per second**: Peticiones por segundo
- **Time per request**: Tiempo promedio por petición
- **Failed requests**: Peticiones fallidas (debe ser 0)

### 4.2 Prueba de Carga con curl en Paralelo

```bash
#!/bin/bash
# test-carga-paralela.sh

echo "=== Prueba de Carga Paralela ==="
echo ""

# 50 peticiones en paralelo
for i in {1..50}; do
    curl -s http://localhost > /dev/null &
done

wait
echo "50 peticiones completadas"
```

### 4.3 Monitoreo de Recursos

**Durante las pruebas, monitorea recursos:**

```bash
# En una terminal, monitorea CPU y memoria
watch -n 1 'free -h && echo "" && top -bn1 | head -5'

# En otra terminal, monitorea conexiones
watch -n 1 'netstat -an | grep :80 | wc -l'
```

## Parte 5: Pruebas de Alta Disponibilidad

### 5.1 Prueba de Failover

**Escenario:** Un servidor backend falla, el tráfico debe continuar.

1. **Iniciar tráfico continuo:**

```bash
#!/bin/bash
# test-failover.sh

while true; do
    response=$(curl -s -w "\nHTTP Status: %{http_code}\n" http://localhost)
    echo "$response"
    echo "---"
    sleep 1
done
```

2. **En otra terminal, detener un backend:**

```bash
ssh ubuntu@192.168.100.10
sudo systemctl stop apache2
```

3. **Observar:** El tráfico debe continuar solo hacia el servidor activo.

4. **Reactivar el servidor:**

```bash
sudo systemctl start apache2
```

5. **Observar:** El tráfico debe volver a distribuirse.

### 5.2 Prueba de Recuperación Automática

```bash
#!/bin/bash
# test-recuperacion.sh

echo "=== Prueba de Recuperación Automática ==="
echo ""

# Detener backend 1
echo "1. Deteniendo web-backend-1..."
ssh ubuntu@192.168.100.10 "sudo systemctl stop apache2"

echo "2. Esperando 5 segundos..."
sleep 5

echo "3. Verificando que solo backend-2 responde..."
for i in {1..5}; do
    curl -s http://localhost | grep "Backend Server"
done

echo ""
echo "4. Reactivando web-backend-1..."
ssh ubuntu@192.168.100.10 "sudo systemctl start apache2"

echo "5. Esperando 10 segundos para recuperación..."
sleep 10

echo "6. Verificando que ambos servidores responden..."
for i in {1..10}; do
    curl -s http://localhost | grep "Backend Server"
done
```

## Parte 6: Pruebas de Sticky Sessions (si configurado)

### 6.1 Verificar Sticky Sessions

Si configuraste sticky sessions (IP hash), la misma IP siempre debe ir al mismo servidor:

```bash
#!/bin/bash
# test-sticky-sessions.sh

echo "=== Prueba de Sticky Sessions ==="
echo ""

# Hacer 10 peticiones desde la misma IP
for i in {1..10}; do
    server=$(curl -s http://localhost | grep -o "Backend Server [0-9]" | head -1)
    echo "Petición $i: $server"
done

echo ""
echo "Si sticky sessions está activo, todas deberían ser del mismo servidor"
```

## Parte 7: Verificación desde Navegador

### 7.1 Prueba Manual

1. Abre tu navegador
2. Ve a `http://<IP_FLOTANTE_BALANCER>`
3. Refresca la página múltiples veces (F5 o Ctrl+R)
4. Observa que el color/fondo de la página cambia entre servidores

### 7.2 Usar Herramientas de Desarrollador

1. Abre las herramientas de desarrollador (F12)
2. Ve a la pestaña **Network**
3. Refresca la página varias veces
4. Observa las respuestas - deberías ver diferentes servidores

## Parte 8: Scripts de Verificación Completa

### 8.1 Script de Verificación General

Ver `scripts/verificar-balanceador.sh` para un script completo de verificación.

### 8.2 Script de Monitoreo Continuo

Ver `scripts/monitoreo-continuo.sh` para monitoreo en tiempo real.

## Parte 9: Análisis de Logs

### 9.1 Analizar Logs de HAProxy

```bash
# Ver últimas 50 líneas
sudo tail -n 50 /var/log/haproxy.log

# Buscar errores
sudo grep -i error /var/log/haproxy.log

# Ver peticiones por servidor
sudo grep "web-backend-1" /var/log/haproxy.log | wc -l
sudo grep "web-backend-2" /var/log/haproxy.log | wc -l
```

### 9.2 Analizar Logs de Nginx

```bash
# Ver últimas 50 líneas
sudo tail -n 50 /var/log/nginx/loadbalancer-access.log

# Ver IPs más activas
sudo awk '{print $1}' /var/log/nginx/loadbalancer-access.log | sort | uniq -c | sort -rn | head -10

# Ver códigos de estado
sudo awk '{print $9}' /var/log/nginx/loadbalancer-access.log | sort | uniq -c | sort -rn

# Ver peticiones por minuto
sudo awk '{print $4}' /var/log/nginx/loadbalancer-access.log | cut -d: -f1-2 | uniq -c
```

## Parte 10: Checklist de Verificación

Usa este checklist para verificar que todo funciona:

- [ ] El balanceador responde en el puerto 80
- [ ] Los servidores backend son accesibles individualmente
- [ ] El balanceo distribuye el tráfico entre servidores
- [ ] Los health checks detectan servidores caídos
- [ ] El tráfico continúa cuando un servidor falla
- [ ] Los servidores se reintegran automáticamente
- [ ] Las estadísticas son accesibles (HAProxy: :8404/stats, Nginx: /nginx_status)
- [ ] Los logs registran correctamente las peticiones
- [ ] El rendimiento es aceptable (sin timeouts, errores mínimos)
- [ ] Desde el navegador se puede acceder y ver el balanceo

## Troubleshooting Común

### Problema: Todas las peticiones van al mismo servidor

**Posibles causas:**
- Sticky sessions activado (comportamiento esperado)
- Un servidor está marcado como DOWN
- Configuración incorrecta del algoritmo de balanceo

**Solución:**
- Verifica las estadísticas del balanceador
- Verifica el estado de los servidores backend
- Revisa la configuración del algoritmo de balanceo

### Problema: Error 502 Bad Gateway

**Posibles causas:**
- Servidores backend no están funcionando
- Problemas de conectividad de red
- Firewall bloqueando tráfico

**Solución:**
- Verifica que los backend estén corriendo
- Prueba conectividad: `ping` y `curl` desde el balanceador
- Verifica grupos de seguridad en OpenStack

### Problema: Health checks no funcionan

**Posibles causas:**
- Configuración incorrecta de health checks
- Servidores backend no responden correctamente
- Timeouts muy cortos

**Solución:**
- Verifica la configuración de health checks
- Prueba manualmente: `curl http://192.168.100.10`
- Ajusta los timeouts si es necesario

### Problema: Rendimiento bajo

**Posibles causas:**
- Recursos insuficientes en las instancias
- Configuración subóptima
- Red lenta

**Solución:**
- Monitorea recursos (CPU, memoria, red)
- Considera aumentar el tamaño de las instancias
- Optimiza la configuración del balanceador

## Siguiente Paso

Una vez que hayas verificado que todo funciona correctamente:
- Documenta tu configuración
- Considera implementar monitoreo automático
- Planifica la configuración de producción (SSL, autenticación, etc.)

