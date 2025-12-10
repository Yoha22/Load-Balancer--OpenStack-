# Guía 2: Configuración de Servidores Web Backend

Esta guía te ayudará a configurar los servidores web backend que serán balanceados por HAProxy o Nginx.

## Prerrequisitos

- Instancias backend creadas en OpenStack (mínimo 2)
- Acceso SSH a cada instancia backend
- IPs de las instancias (pueden ser IPs privadas o flotantes)

## Paso 1: Conectarse a las Instancias Backend

### 1.1 Obtener IPs de las Instancias

```bash
# Desde tu máquina local o desde el balanceador
openstack server list

# O desde el dashboard, ve a Compute → Instances
```

Anota las IPs privadas de tus instancias backend (ej: `192.168.100.10`, `192.168.100.11`).

### 1.2 Conectarse por SSH

```bash
# Conectarse a web-backend-1
ssh -i <TU_KEY_FILE> ubuntu@<IP_BACKEND_1>

# En otra terminal, conectarse a web-backend-2
ssh -i <TU_KEY_FILE> ubuntu@<IP_BACKEND_2>
```

**Nota**: Si no tienes IPs flotantes asignadas a los backend, puedes conectarte desde el balanceador usando las IPs privadas.

## Paso 2: Actualizar el Sistema

Ejecuta en **cada instancia backend**:

```bash
sudo apt update
sudo apt upgrade -y
```

## Paso 3: Instalar Servidor Web

Tienes dos opciones: Apache o Nginx. Te mostramos ambas.

### Opción A: Instalar Apache

```bash
sudo apt install apache2 -y

# Verificar que Apache esté corriendo
sudo systemctl status apache2

# Habilitar Apache para que inicie al arrancar
sudo systemctl enable apache2
```

### Opción B: Instalar Nginx

```bash
sudo apt install nginx -y

# Verificar que Nginx esté corriendo
sudo systemctl status nginx

# Habilitar Nginx para que inicie al arrancar
sudo systemctl enable nginx
```

**Recomendación**: Usa Apache para simplicidad, o Nginx si prefieres un servidor más ligero.

## Paso 4: Configurar Firewall

### 4.1 Permitir Tráfico HTTP

```bash
# Si usas UFW (Ubuntu Firewall)
sudo ufw allow 'Apache Full'  # Para Apache
# O
sudo ufw allow 'Nginx Full'   # Para Nginx

# O específicamente:
sudo ufw allow 80/tcp
sudo ufw allow 22/tcp

# Verificar estado
sudo ufw status
```

### 4.2 (Opcional) Verificar que el Firewall Esté Activo

```bash
sudo ufw enable
```

## Paso 5: Crear Páginas de Prueba Identificables

Necesitamos crear páginas HTML que identifiquen claramente cada servidor para verificar que el balanceo funciona.

### 5.1 Para web-backend-1

```bash
# Si usas Apache
sudo nano /var/www/html/index.html

# Si usas Nginx
sudo nano /var/www/html/index.html
# O en algunas versiones:
sudo nano /usr/share/nginx/html/index.html
```

**Contenido para web-backend-1:**

```html
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Backend Server 1</title>
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
        <h1>🚀 Backend Server 1</h1>
        <div class="server-info">
            <p><strong>Servidor:</strong> web-backend-1</p>
            <div class="ip-address">
                IP: <?php echo $_SERVER['SERVER_ADDR']; ?>
            </div>
            <p style="margin-top: 20px;">Este es el servidor backend número 1</p>
            <p style="font-size: 0.9em; opacity: 0.8;">Timestamp: <?php echo date('Y-m-d H:i:s'); ?></p>
        </div>
    </div>
</body>
</html>
```

**Si prefieres HTML puro (sin PHP):**

```html
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Backend Server 1</title>
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
        <h1>🚀 Backend Server 1</h1>
        <div class="server-info">
            <p><strong>Servidor:</strong> web-backend-1</p>
            <div class="ip-address">
                IP: 192.168.100.10
            </div>
            <p style="margin-top: 20px;">Este es el servidor backend número 1</p>
            <p style="font-size: 0.9em; opacity: 0.8;">Sistema funcionando correctamente</p>
        </div>
    </div>
</body>
</html>
```

Guarda el archivo (Ctrl+O, Enter, Ctrl+X en nano).

### 5.2 Para web-backend-2

Conéctate a la segunda instancia y crea un archivo similar pero con información diferente:

```bash
# Si usas Apache
sudo nano /var/www/html/index.html

# Si usas Nginx
sudo nano /var/www/html/index.html
```

**Contenido para web-backend-2 (con colores diferentes):**

```html
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Backend Server 2</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
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
        <h1>🌟 Backend Server 2</h1>
        <div class="server-info">
            <p><strong>Servidor:</strong> web-backend-2</p>
            <div class="ip-address">
                IP: 192.168.100.11
            </div>
            <p style="margin-top: 20px;">Este es el servidor backend número 2</p>
            <p style="font-size: 0.9em; opacity: 0.8;">Sistema funcionando correctamente</p>
        </div>
    </div>
</body>
</html>
```

**Nota**: Cambia las IPs por las IPs privadas reales de tus instancias.

### 5.3 (Opcional) Instalar PHP para Información Dinámica

Si quieres mostrar información dinámica (IP, timestamp, etc.), instala PHP:

```bash
# Para Apache
sudo apt install php libapache2-mod-php -y
sudo systemctl restart apache2

# Para Nginx
sudo apt install php-fpm -y
sudo systemctl restart nginx
```

## Paso 6: Verificar que los Servidores Funcionan

### 6.1 Verificar desde la Misma Instancia

```bash
# Desde web-backend-1
curl http://localhost
# O
curl http://192.168.100.10

# Desde web-backend-2
curl http://localhost
# O
curl http://192.168.100.11
```

### 6.2 Verificar desde el Balanceador

Conéctate al balanceador y prueba:

```bash
# Desde la instancia del balanceador
curl http://192.168.100.10
curl http://192.168.100.11
```

Deberías ver el HTML de cada servidor.

### 6.3 Verificar desde Navegador (si tienes IPs flotantes)

Si asignaste IPs flotantes a los backend, puedes abrir en tu navegador:

```
http://<IP_FLOTANTE_BACKEND_1>
http://<IP_FLOTANTE_BACKEND_2>
```

## Paso 7: Configurar Permisos (si es necesario)

```bash
# Para Apache
sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 755 /var/www/html

# Para Nginx
sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 755 /var/www/html
```

## Paso 8: Verificar Estado de los Servicios

```bash
# Para Apache
sudo systemctl status apache2
sudo systemctl is-enabled apache2

# Para Nginx
sudo systemctl status nginx
sudo systemctl is-enabled nginx
```

## Resumen de Configuración

Al finalizar esta guía, cada instancia backend debería tener:

- ✅ Servidor web (Apache o Nginx) instalado y funcionando
- ✅ Firewall configurado para permitir tráfico HTTP
- ✅ Página HTML de prueba única que identifica el servidor
- ✅ Servicio web accesible desde otras instancias de la red
- ✅ Servicio configurado para iniciar automáticamente

## Verificación Final

Ejecuta este script de verificación en cada backend:

```bash
#!/bin/bash
echo "=== Verificación Backend Server ==="
echo "IP Privada:"
hostname -I | awk '{print $1}'
echo ""
echo "Estado del servidor web:"
systemctl is-active apache2 2>/dev/null || systemctl is-active nginx
echo ""
echo "Prueba de respuesta HTTP:"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://localhost
echo ""
echo "Contenido de la página:"
curl -s http://localhost | head -5
```

## Siguiente Paso

Una vez que ambos servidores backend estén funcionando correctamente, procede con:
- **Guía 3: Configuración de HAProxy** (si prefieres HAProxy)
- **Guía 4: Configuración de Nginx** (si prefieres Nginx como balanceador)

## Troubleshooting

### Problema: No puedo acceder al servidor web
- **Solución**: 
  - Verifica que el servicio esté corriendo: `sudo systemctl status apache2` o `sudo systemctl status nginx`
  - Verifica el firewall: `sudo ufw status`
  - Verifica los grupos de seguridad en OpenStack

### Problema: Página en blanco o error 403
- **Solución**: 
  - Verifica permisos: `ls -la /var/www/html`
  - Ajusta permisos: `sudo chmod 755 /var/www/html` y `sudo chown -R www-data:www-data /var/www/html`

### Problema: No puedo conectarme desde el balanceador
- **Solución**: 
  - Verifica que ambas instancias estén en la misma red
  - Verifica que los grupos de seguridad permitan tráfico interno
  - Prueba con `ping` desde el balanceador: `ping 192.168.100.10`

### Problema: El servicio no inicia automáticamente
- **Solución**: 
  - Habilita el servicio: `sudo systemctl enable apache2` o `sudo systemctl enable nginx`

