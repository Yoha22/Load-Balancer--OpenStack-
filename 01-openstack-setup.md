# Guía 1: Configuración de OpenStack

Esta guía te ayudará a configurar OpenStack para crear las instancias necesarias para el balanceador de carga.

## Prerrequisitos

- Ubuntu Server instalado
- Acceso root o sudo
- Conexión a Internet

## Paso 0: Configuración del Entorno - Ubuntu Server con Interfaz Gráfica

Esta guía asume que estás usando Ubuntu Server con interfaz gráfica XFCE configurada con lightdm.

### 0.1 Instalar Interfaz Gráfica XFCE

```bash
sudo apt update
sudo apt install xfce4 xfce4-goodies -y
```

Esto instalará el entorno de escritorio XFCE junto con aplicaciones adicionales útiles.

### 0.2 Instalar y Configurar lightdm

```bash
sudo apt install lightdm -y
sudo systemctl enable lightdm
```

**Nota Importante**: Usamos `lightdm` como display manager en lugar de `startx` porque lightdm es más adecuado para entornos de servidor y proporciona un mejor manejo de sesiones gráficas. Lightdm se encarga automáticamente de iniciar la sesión gráfica al arrancar el sistema, a diferencia de `startx` que requiere iniciarse manualmente.

### 0.3 Reiniciar y Verificar

```bash
sudo reboot
```

Después del reinicio, se iniciará automáticamente la interfaz gráfica XFCE usando lightdm. Verás la pantalla de inicio de sesión de lightdm, donde podrás ingresar con tu usuario y contraseña.

### 0.4 Verificar la Instalación

Una vez iniciada la sesión gráfica, puedes verificar que todo funciona correctamente:

- La interfaz gráfica XFCE debería estar activa
- Puedes abrir aplicaciones desde el menú
- Puedes acceder a la terminal gráfica

## Paso 1: Instalación de OpenStack con MicroStack

MicroStack es una distribución de OpenStack simplificada que se instala fácilmente usando snap. Está diseñada para entornos de desarrollo, pruebas y despliegues pequeños.

### 1.1 Instalar MicroStack

```bash
snap install microstack --beta
```

Este comando instalará MicroStack desde el canal beta de snap. La instalación puede tomar varios minutos dependiendo de tu conexión a Internet y el rendimiento del sistema.

### 1.2 Inicializar MicroStack

```bash
sudo microstack init --auto --control
```

Este comando configura MicroStack automáticamente como nodo de control. Durante la inicialización, MicroStack:
- Configura los servicios principales de OpenStack (Nova, Neutron, Glance, etc.)
- Crea una red por defecto
- Configura las credenciales de administrador
- Establece la configuración básica necesaria

**Nota**: El proceso de inicialización puede tardar varios minutos. Asegúrate de tener suficiente espacio en disco y recursos del sistema disponibles.

### 1.3 Verificar Instalación

Una vez completada la instalación, verifica el estado:

```bash
# Verificar estado de los servicios
sudo microstack status
```

Deberías ver todos los servicios de OpenStack corriendo correctamente.

### 1.4 Configurar Variables de Entorno

Para usar los comandos CLI de OpenStack, necesitas configurar las variables de entorno:

```bash
source /var/snap/microstack/common/etc/admin-openrc.sh
```

Puedes agregar esta línea a tu archivo `~/.bashrc` para que se cargue automáticamente en cada sesión:

```bash
echo "source /var/snap/microstack/common/etc/admin-openrc.sh" >> ~/.bashrc
source ~/.bashrc
```

### 1.5 Verificar Acceso CLI

Prueba que el CLI de OpenStack funciona correctamente:

```bash
openstack --version
openstack service list
```

Deberías ver la versión de OpenStack y una lista de servicios disponibles.

### 1.6 (Opcional) Acceder al Dashboard Horizon

MicroStack puede configurar el dashboard web de Horizon. Para verificar si está disponible:

```bash
sudo microstack.openstack endpoint list | grep -i horizon
```

Si Horizon está disponible, puedes acceder desde un navegador usando la URL mostrada. Las credenciales por defecto generalmente son:
- Usuario: `admin`
- Contraseña: Verifica con `sudo snap get microstack config.credentials.keystone-password` o revisa la salida de `microstack init`

**Nota importante sobre MicroStack**: Los comandos CLI de OpenStack que se usarán en los siguientes pasos funcionan de la misma manera con MicroStack, ya que MicroStack implementa las mismas APIs de OpenStack estándar. Si prefieres usar el dashboard (Horizon), también puedes hacerlo desde la interfaz gráfica, pero esta guía se enfoca principalmente en el uso de CLI.

## Paso 2: Crear Red y Subred

### 2.1 Crear Red Privada

**Opción A: Desde el Dashboard (Horizon)**

**Nota para MicroStack**: Si Horizon no está disponible o prefieres usar solo CLI, puedes usar la Opción B (CLI). Los comandos CLI funcionan de la misma manera con MicroStack.

1. Inicia sesión en el dashboard de OpenStack
2. Ve a **Network** → **Networks**
3. Haz clic en **Create Network**
4. Configura:
   - **Network Name**: `load-balancer-network`
   - **Admin State**: Up
   - Haz clic en **Next**

**Opción B: Desde la CLI**

```bash
openstack network create load-balancer-network
```

### 2.2 Crear Subred

**Opción A: Desde el Dashboard**

1. En la creación de red, en la pestaña **Subnet**:
   - **Subnet Name**: `load-balancer-subnet`
   - **Network Address**: `192.168.100.0/24` (o el rango que prefieras)
   - **IP Version**: IPv4
   - **Gateway IP**: `192.168.100.1` (o dejar automático)
   - Haz clic en **Next**

2. En **Subnet Details**:
   - **Enable DHCP**: Sí
   - **DNS Name Servers**: Puedes usar `8.8.8.8` y `8.8.4.4`
   - Haz clic en **Create**

**Opción B: Desde la CLI**

```bash
openstack subnet create \
  --network load-balancer-network \
  --subnet-range 192.168.100.0/24 \
  --gateway 192.168.100.1 \
  --dns-nameserver 8.8.8.8 \
  --dns-nameserver 8.8.4.4 \
  load-balancer-subnet
```

## Paso 3: Crear Router

### 3.1 Crear Router

**Opción A: Desde el Dashboard**

1. Ve a **Network** → **Routers**
2. Haz clic en **Create Router**
3. Configura:
   - **Router Name**: `load-balancer-router`
   - **Admin State**: Up
   - **External Network**: Selecciona la red externa (generalmente `public` o `ext-net`)
   - Haz clic en **Create Router**

**Opción B: Desde la CLI**

```bash
# Primero, identifica la red externa
openstack network list --external

# Crea el router
openstack router create load-balancer-router

# Conecta el router a la red externa
openstack router set --external-gateway <EXTERNAL_NETWORK_ID> load-balancer-router
```

**Nota para MicroStack**: MicroStack puede crear una red externa automáticamente durante la inicialización. Usa `openstack network list --external` para ver las redes externas disponibles. En MicroStack, la red externa suele llamarse `external` o tener un nombre similar.

### 3.2 Conectar Router a la Subred

**Opción A: Desde el Dashboard**

1. Ve a **Network** → **Routers**
2. Haz clic en `load-balancer-router`
3. Ve a la pestaña **Interfaces**
4. Haz clic en **Add Interface**
5. Selecciona:
   - **Subnet**: `load-balancer-subnet`
   - Haz clic en **Submit**

**Opción B: Desde la CLI**

```bash
openstack router add subnet load-balancer-router load-balancer-subnet
```

## Paso 4: Configurar Grupos de Seguridad

### 4.1 Crear Grupo de Seguridad para Balanceador

**Opción A: Desde el Dashboard**

1. Ve a **Network** → **Security Groups**
2. Haz clic en **Create Security Group**
3. Configura:
   - **Name**: `load-balancer-sg`
   - **Description**: `Security group for load balancer`
   - Haz clic en **Create Security Group**

4. Haz clic en **Manage Rules** del grupo creado
5. Agrega las siguientes reglas:

   **Regla 1: HTTP (Puerto 80)**
   - **Direction**: Ingress
   - **Ether Type**: IPv4
   - **IP Protocol**: TCP
   - **Port**: 80
   - **Remote**: CIDR `0.0.0.0/0` (o un rango específico)
   - Haz clic en **Add**

   **Regla 2: HTTPS (Puerto 443)**
   - **Direction**: Ingress
   - **Ether Type**: IPv4
   - **IP Protocol**: TCP
   - **Port**: 443
   - **Remote**: CIDR `0.0.0.0/0`
   - Haz clic en **Add**

   **Regla 3: SSH (Puerto 22)**
   - **Direction**: Ingress
   - **Ether Type**: IPv4
   - **IP Protocol**: TCP
   - **Port**: 22
   - **Remote**: CIDR `0.0.0.0/0` (o tu IP específica para mayor seguridad)
   - Haz clic en **Add**

**Opción B: Desde la CLI**

```bash
# Crear grupo de seguridad
openstack security group create load-balancer-sg \
  --description "Security group for load balancer"

# Agregar reglas
openstack security group rule create \
  --protocol tcp \
  --dst-port 80 \
  --remote-ip 0.0.0.0/0 \
  load-balancer-sg

openstack security group rule create \
  --protocol tcp \
  --dst-port 443 \
  --remote-ip 0.0.0.0/0 \
  load-balancer-sg

openstack security group rule create \
  --protocol tcp \
  --dst-port 22 \
  --remote-ip 0.0.0.0/0 \
  load-balancer-sg
```

### 4.2 Crear Grupo de Seguridad para Backend Servers

**Opción A: Desde el Dashboard**

1. Crea un nuevo grupo de seguridad llamado `backend-servers-sg`
2. Agrega las siguientes reglas:
   - **HTTP (Puerto 80)**: Ingress, TCP, Port 80, desde `load-balancer-sg` o `192.168.100.0/24`
   - **SSH (Puerto 22)**: Ingress, TCP, Port 22, desde tu IP o `0.0.0.0/0`

**Opción B: Desde la CLI**

```bash
# Crear grupo de seguridad para backend
openstack security group create backend-servers-sg \
  --description "Security group for backend web servers"

# Permitir HTTP desde la red interna
openstack security group rule create \
  --protocol tcp \
  --dst-port 80 \
  --remote-ip 192.168.100.0/24 \
  backend-servers-sg

# Permitir SSH
openstack security group rule create \
  --protocol tcp \
  --dst-port 22 \
  --remote-ip 0.0.0.0/0 \
  backend-servers-sg
```

## Paso 5: Crear Instancias

### 5.1 Crear Instancia del Balanceador

**Opción A: Desde el Dashboard**

1. Ve a **Compute** → **Instances**
2. Haz clic en **Launch Instance**
3. Configura la pestaña **Details**:
   - **Instance Name**: `load-balancer`
   - **Flavor**: Selecciona un sabor apropiado (ej: `m1.small` o `m1.medium`)
   - **Instance Count**: 1
   - Haz clic en **Next**

4. En **Source**:
   - **Select Boot Source**: Image
   - Selecciona una imagen de Ubuntu Server (ej: `Ubuntu 22.04 LTS`)
   - Haz clic en **Next**

5. En **Flavor**:
   - Confirma el flavor seleccionado
   - Haz clic en **Next**

6. En **Networks**:
   - Selecciona `load-balancer-network`
   - Haz clic en **Next**

7. En **Security Groups**:
   - Selecciona `load-balancer-sg`
   - Haz clic en **Next**

8. En **Key Pair**:
   - Selecciona o crea un par de claves SSH
   - Haz clic en **Launch Instance**

**Opción B: Desde la CLI**

```bash
# Listar imágenes disponibles
openstack image list

# Listar flavors disponibles
openstack flavor list

# Crear instancia del balanceador
openstack server create \
  --image <UBUNTU_IMAGE_ID> \
  --flavor <FLAVOR_ID> \
  --network load-balancer-network \
  --security-group load-balancer-sg \
  --key-name <TU_KEY_PAIR_NAME> \
  load-balancer
```

### 5.2 Crear Instancias Backend (Mínimo 2)

Repite el proceso anterior para crear al menos 2 instancias backend:

- **Nombre**: `web-backend-1`, `web-backend-2` (y más si lo deseas)
- **Network**: `load-balancer-network`
- **Security Group**: `backend-servers-sg`
- **Flavor**: Puede ser más pequeño que el balanceador

**Comando CLI para múltiples instancias:**

```bash
# Crear web-backend-1
openstack server create \
  --image <UBUNTU_IMAGE_ID> \
  --flavor <FLAVOR_ID> \
  --network load-balancer-network \
  --security-group backend-servers-sg \
  --key-name <TU_KEY_PAIR_NAME> \
  web-backend-1

# Crear web-backend-2
openstack server create \
  --image <UBUNTU_IMAGE_ID> \
  --flavor <FLAVOR_ID> \
  --network load-balancer-network \
  --security-group backend-servers-sg \
  --key-name <TU_KEY_PAIR_NAME> \
  web-backend-2
```

## Paso 6: Asignar IPs Flotantes

### 6.1 Asignar IP Flotante al Balanceador

**Opción A: Desde el Dashboard**

1. Ve a **Compute** → **Instances**
2. Haz clic en el menú desplegable de la instancia `load-balancer`
3. Selecciona **Associate Floating IP**
4. Si no tienes IPs disponibles, haz clic en **+** para asignar una nueva
5. Selecciona la IP y haz clic en **Associate**

**Opción B: Desde la CLI**

```bash
# Listar pools de IPs flotantes
openstack floating ip list

# Asignar IP flotante al balanceador
openstack floating ip create <EXTERNAL_NETWORK_NAME>
openstack server add floating ip load-balancer <FLOATING_IP>
```

**Nota para MicroStack**: En MicroStack, las IPs flotantes se gestionan de la misma manera que en OpenStack estándar. Asegúrate de que la red externa esté configurada correctamente antes de crear IPs flotantes.

### 6.2 (Opcional) Asignar IPs Flotantes a Backend Servers

Para facilitar el acceso directo a los servidores backend, puedes asignarles IPs flotantes también.

## Paso 7: Verificar Configuración

### 7.1 Verificar Estado de las Instancias

```bash
openstack server list
```

Todas las instancias deben estar en estado `ACTIVE`.

### 7.2 Verificar Conectividad de Red

```bash
# Ver detalles de la red
openstack network show load-balancer-network

# Ver detalles de la subred
openstack subnet show load-balancer-subnet

# Ver detalles del router
openstack router show load-balancer-router
```

### 7.3 Probar Conectividad SSH

```bash
# Conectarse al balanceador
ssh -i <TU_KEY_FILE> ubuntu@<FLOATING_IP_BALANCER>

# Conectarse a los backend (si tienen IP flotante)
ssh -i <TU_KEY_FILE> ubuntu@<FLOATING_IP_BACKEND_1>
ssh -i <TU_KEY_FILE> ubuntu@<FLOATING_IP_BACKEND_2>
```

## Resumen de Configuración

Al finalizar esta guía, deberías tener:

- ✅ Red `load-balancer-network` con subred `192.168.100.0/24`
- ✅ Router `load-balancer-router` conectado a red externa e interna
- ✅ Grupo de seguridad `load-balancer-sg` (puertos 22, 80, 443)
- ✅ Grupo de seguridad `backend-servers-sg` (puertos 22, 80)
- ✅ Instancia `load-balancer` con IP flotante
- ✅ Mínimo 2 instancias backend (`web-backend-1`, `web-backend-2`)
- ✅ Todas las instancias en estado `ACTIVE`

## Siguiente Paso

Una vez completada esta configuración, procede con la **Guía 2: Configuración de Servidores Web Backend**.

## Troubleshooting

### Problema: No puedo crear la red
- **Solución**: Verifica que tengas permisos de administrador o de creación de redes en el proyecto.

### Problema: No hay IPs flotantes disponibles
- **Solución**: Contacta al administrador de OpenStack o verifica el pool de IPs flotantes.

### Problema: No puedo conectarme por SSH
- **Solución**: 
  - Verifica que el grupo de seguridad permita el puerto 22
  - Verifica que la instancia esté en estado `ACTIVE`
  - Verifica que el par de claves sea correcto
  - Verifica que la IP flotante esté asignada correctamente

### Problema: Las instancias no pueden comunicarse entre sí
- **Solución**: 
  - Verifica que todas estén en la misma red
  - Verifica los grupos de seguridad (deben permitir tráfico interno)
  - Verifica que el router esté conectado correctamente

