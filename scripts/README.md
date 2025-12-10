# Scripts Auxiliares para Balanceador de Carga

Este directorio contiene scripts útiles para automatizar la instalación, configuración y pruebas del balanceador de carga.

## Scripts de Instalación

### `instalar-backend.sh`
Instala y configura un servidor web backend con Apache.

**Uso:**
```bash
chmod +x instalar-backend.sh
./instalar-backend.sh <numero_servidor> <ip_privada>
```

**Ejemplo:**
```bash
./instalar-backend.sh 1 192.168.100.10
./instalar-backend.sh 2 192.168.100.11
```

### `instalar-haproxy.sh`
Instala y configura HAProxy como balanceador de carga.

**Uso:**
```bash
chmod +x instalar-haproxy.sh
./instalar-haproxy.sh <ip_backend_1> <ip_backend_2> [ip_backend_3] ...
```

**Ejemplo:**
```bash
./instalar-haproxy.sh 192.168.100.10 192.168.100.11
```

### `instalar-nginx-lb.sh`
Instala y configura Nginx como balanceador de carga.

**Uso:**
```bash
chmod +x instalar-nginx-lb.sh
./instalar-nginx-lb.sh <ip_backend_1> <ip_backend_2> [ip_backend_3] ...
```

**Ejemplo:**
```bash
./instalar-nginx-lb.sh 192.168.100.10 192.168.100.11
```

## Scripts de Prueba

### `test-balanceo.sh`
Prueba el balanceo de carga realizando múltiples peticiones y mostrando la distribución.

**Uso:**
```bash
chmod +x test-balanceo.sh
./test-balanceo.sh [numero_peticiones] [url]
```

**Ejemplo:**
```bash
./test-balanceo.sh 50 http://localhost
```

### `verificar-balanceador.sh`
Realiza una verificación completa del balanceador de carga.

**Uso:**
```bash
chmod +x verificar-balanceador.sh
./verificar-balanceador.sh [tipo] [url]
```

**Ejemplo:**
```bash
./verificar-balanceador.sh haproxy http://localhost
./verificar-balanceador.sh nginx http://localhost
./verificar-balanceador.sh auto http://localhost  # Auto-detecta el tipo
```

### `monitoreo-continuo.sh`
Monitorea el balanceador de forma continua mostrando el estado en tiempo real.

**Uso:**
```bash
chmod +x monitoreo-continuo.sh
./monitoreo-continuo.sh [url] [intervalo_segundos]
```

**Ejemplo:**
```bash
./monitoreo-continuo.sh http://localhost 5
```

### `test-failover.sh`
Prueba el failover (alta disponibilidad) deteniendo y reactivando servidores backend.

**Uso:**
```bash
chmod +x test-failover.sh
./test-failover.sh <ip_backend_1> <ip_backend_2> [url_balanceador]
```

**Ejemplo:**
```bash
./test-failover.sh 192.168.100.10 192.168.100.11 http://localhost
```

**Nota:** Este script requiere acceso SSH sin contraseña a los servidores backend (usando claves SSH).

## Uso General

1. **Copiar los scripts a las instancias correspondientes:**
   - Scripts de backend → instancias backend
   - Scripts de balanceador → instancia del balanceador

2. **Hacer los scripts ejecutables:**
   ```bash
   chmod +x *.sh
   ```

3. **Ejecutar según sea necesario:**
   ```bash
   ./nombre-del-script.sh [argumentos]
   ```

## Requisitos

- Bash 4.0 o superior
- Acceso sudo en las instancias
- Conectividad de red entre instancias
- curl instalado (generalmente viene preinstalado)

## Notas

- Los scripts asumen que estás usando Ubuntu Server
- Algunos scripts requieren acceso SSH sin contraseña a otras instancias
- Ajusta las IPs y configuraciones según tu entorno
- Los scripts de instalación hacen backups de configuraciones existentes

## Troubleshooting

Si un script falla:
1. Verifica que tienes permisos de ejecución: `chmod +x script.sh`
2. Verifica que tienes permisos sudo
3. Revisa los mensajes de error en la salida
4. Verifica la conectividad de red
5. Asegúrate de que los servicios necesarios estén instalados

