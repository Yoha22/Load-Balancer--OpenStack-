# Guía 1: Configuración de OpenStack

Esta guía te ayudará a configurar OpenStack para crear las instancias necesarias para el balanceador de carga.

## Prerrequisitos

- Acceso al dashboard de OpenStack (Horizon) o CLI de OpenStack
- Credenciales de acceso (usuario, contraseña, proyecto)
- Permisos para crear redes, routers e instancias

## Paso 1: Crear Red y Subred

### 1.1 Crear Red Privada

**Opción A: Desde el Dashboard (Horizon)**

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

### 1.2 Crear Subred

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

## Paso 2: Crear Router

### 2.1 Crear Router

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

### 2.2 Conectar Router a la Subred

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

## Paso 3: Configurar Grupos de Seguridad

### 3.1 Crear Grupo de Seguridad para Balanceador

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

### 3.2 Crear Grupo de Seguridad para Backend Servers

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

## Paso 4: Crear Instancias

### 4.1 Crear Instancia del Balanceador

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

### 4.2 Crear Instancias Backend (Mínimo 2)

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

## Paso 5: Asignar IPs Flotantes

### 5.1 Asignar IP Flotante al Balanceador

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

### 5.2 (Opcional) Asignar IPs Flotantes a Backend Servers

Para facilitar el acceso directo a los servidores backend, puedes asignarles IPs flotantes también.

## Paso 6: Verificar Configuración

### 6.1 Verificar Estado de las Instancias

```bash
openstack server list
```

Todas las instancias deben estar en estado `ACTIVE`.

### 6.2 Verificar Conectividad de Red

```bash
# Ver detalles de la red
openstack network show load-balancer-network

# Ver detalles de la subred
openstack subnet show load-balancer-subnet

# Ver detalles del router
openstack router show load-balancer-router
```

### 6.3 Probar Conectividad SSH

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

