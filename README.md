# Guía Completa: Balanceador de Carga con HAProxy y Nginx en OpenStack

Esta guía te ayudará a implementar un balanceador de carga completo usando HAProxy o Nginx en OpenStack, balanceando tráfico hacia múltiples instancias web backend.

## 📋 Contenido

Esta guía está organizada en los siguientes documentos:

1. **[01-openstack-setup.md](01-openstack-setup.md)** - Configuración inicial de OpenStack
   - Configuración del entorno: Ubuntu Server con interfaz gráfica (XFCE + lightdm)
   - Instalación de OpenStack usando MicroStack con snap
   - Creación de red y subred
   - Creación de router
   - Configuración de grupos de seguridad
   - Creación de instancias

2. **[02-backend-servers-setup.md](02-backend-servers-setup.md)** - Configuración de servidores web backend
   - Instalación de servidor web (Apache/Nginx)
   - Configuración de aplicaciones de prueba
   - Verificación individual de cada servidor

3. **[03-haproxy-setup.md](03-haproxy-setup.md)** - Configuración de HAProxy
   - Instalación de HAProxy
   - Configuración del balanceador
   - Algoritmos de balanceo
   - Health checks
   - Configuración de logs

4. **[04-nginx-setup.md](04-nginx-setup.md)** - Configuración de Nginx como balanceador
   - Instalación de Nginx
   - Configuración upstream
   - Métodos de balanceo
   - Health checks
   - Configuración de logs

5. **[05-testing-verification.md](05-testing-verification.md)** - Pruebas y verificación
   - Scripts de prueba
   - Verificación de balanceo
   - Pruebas de alta disponibilidad
   - Troubleshooting

6. **[scripts/](scripts/)** - Scripts auxiliares
   - Scripts de instalación automatizada
   - Scripts de prueba
   - Scripts de monitoreo

## 🏗️ Arquitectura del Sistema

```
                    ┌─────────────────┐
                    │   Internet      │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  IP Flotante    │
                    │  (Balanceador)  │
                    └────────┬────────┘
                             │
              ┌──────────────┴──────────────┐
              │                             │
    ┌─────────▼─────────┐       ┌─────────▼─────────┐
    │   HAProxy/Nginx   │       │   (Opcional)      │
    │   Balanceador     │       │   Segundo LB      │
    └─────────┬─────────┘       └──────────────────┘
              │
    ┌─────────┴─────────┐
    │                   │
┌───▼────┐         ┌───▼────┐
│Backend │         │Backend │
│Server 1│         │Server 2│
└────────┘         └────────┘
```

## 🚀 Inicio Rápido

### Paso 0: Configurar el Entorno Base
Antes de comenzar, asegúrate de tener:
- Ubuntu Server instalado con interfaz gráfica XFCE
- lightdm configurado como display manager
- MicroStack instalado usando snap

### Paso 1: Configurar OpenStack
Sigue la guía [01-openstack-setup.md](01-openstack-setup.md) para:
- Instalar y configurar MicroStack
- Crear la red y subred
- Configurar el router
- Crear grupos de seguridad
- Crear las instancias (1 balanceador + mínimo 2 backend)

### Paso 2: Configurar Backend Servers
Sigue la guía [02-backend-servers-setup.md](02-backend-servers-setup.md) para:
- Instalar servidor web en cada backend
- Configurar páginas de prueba identificables
- Verificar que funcionan individualmente

### Paso 3: Configurar Balanceador
Elige una opción:
- **HAProxy**: Sigue [03-haproxy-setup.md](03-haproxy-setup.md)
- **Nginx**: Sigue [04-nginx-setup.md](04-nginx-setup.md)
- **Ambos**: Configura ambos para comparar

### Paso 4: Probar y Verificar
Sigue la guía [05-testing-verification.md](05-testing-verification.md) para:
- Probar el balanceo de carga
- Verificar health checks
- Probar failover
- Analizar rendimiento

## 📦 Scripts Automatizados

Para facilitar la instalación, puedes usar los scripts en el directorio `scripts/`:

```bash
# En cada backend
./scripts/instalar-backend.sh 1 192.168.100.10
./scripts/instalar-backend.sh 2 192.168.100.11

# En el balanceador
./scripts/instalar-haproxy.sh 192.168.100.10 192.168.100.11
# O
./scripts/instalar-nginx-lb.sh 192.168.100.10 192.168.100.11
```

Ver [scripts/README.md](scripts/README.md) para más información.

## 🔧 Requisitos

### Requisitos del Sistema Base

- **Ubuntu Server** instalado (recomendado: Ubuntu 22.04 LTS o superior)
- **Interfaz gráfica XFCE** instalada y configurada con **lightdm**
  - XFCE proporciona una interfaz gráfica ligera para el servidor
  - lightdm es el display manager que inicia automáticamente la sesión gráfica (no se usa `startx`)
- **MicroStack** instalado y configurado
  - Instalación mediante snap: `snap install microstack --beta`
  - Inicialización: `sudo microstack init --auto --control`
- Acceso root o sudo en el sistema
- Conexión a Internet para la instalación de paquetes

### Requisitos de OpenStack

- OpenStack (MicroStack) configurado y accesible
- Variables de entorno configuradas para CLI de OpenStack
- Acceso al dashboard Horizon (opcional pero recomendado)

### Requisitos de Instancias

- Acceso SSH a las instancias
- Imagen de Ubuntu Server 22.04 LTS (o similar) disponible en OpenStack
- Mínimo 3 instancias:
  - 1 para el balanceador
  - 2+ para servidores backend

## 📊 Comparación: HAProxy vs Nginx

| Característica | HAProxy | Nginx |
|---------------|---------|-------|
| **Especialización** | Balanceo de carga puro | Servidor web + balanceador |
| **Health Checks** | Muy avanzados | Básicos (mejora con módulos) |
| **Panel Estadísticas** | Integrado y completo | Básico (requiere módulos) |
| **Configuración** | Específica para balanceo | Más versátil |
| **Rendimiento** | Excelente para balanceo | Excelente para servir contenido |
| **Recomendado para** | Balanceo de carga dedicado | Servir contenido + balancear |

## ✅ Checklist de Verificación

- [ ] Red y subred creadas en OpenStack
- [ ] Router configurado y conectado
- [ ] Grupos de seguridad configurados
- [ ] Instancias creadas y en estado ACTIVE
- [ ] IPs flotantes asignadas
- [ ] Servidores backend funcionando individualmente
- [ ] Balanceador instalado y configurado
- [ ] Balanceo funcionando correctamente
- [ ] Health checks detectando servidores
- [ ] Failover funcionando
- [ ] Estadísticas accesibles
- [ ] Logs configurados

## 🐛 Troubleshooting

### Problemas Comunes

**No puedo acceder al balanceador desde Internet**
- Verifica los grupos de seguridad (puerto 80)
- Verifica que la IP flotante esté asignada
- Verifica el firewall en la instancia

**Todos los servidores aparecen como DOWN**
- Verifica conectividad: `ping` y `curl` desde el balanceador
- Verifica que los backend estén funcionando
- Verifica los grupos de seguridad (tráfico interno)

**El balanceo no funciona**
- Verifica que ambos backend estén UP en las estadísticas
- Verifica la configuración del algoritmo de balanceo
- Prueba con múltiples peticiones

Ver la sección de Troubleshooting en cada guía para más detalles.

## 📚 Recursos Adicionales

- [Documentación oficial de HAProxy](http://www.haproxy.org/#docs)
- [Documentación oficial de Nginx](https://nginx.org/en/docs/)
- [Documentación de OpenStack](https://docs.openstack.org/)

## 🔒 Seguridad

**Importante para producción:**
- Cambia las contraseñas por defecto (ej: panel de estadísticas de HAProxy)
- Configura SSL/TLS para HTTPS
- Restringe acceso a paneles de estadísticas
- Usa grupos de seguridad restrictivos
- Implementa autenticación adicional si es necesario
- Monitorea logs regularmente

## 📝 Notas

- Esta guía está diseñada para entornos de aprendizaje y pruebas
- Para producción, considera configuraciones adicionales de seguridad
- Los scripts asumen Ubuntu Server como sistema operativo
- Ajusta las IPs y configuraciones según tu entorno específico

## 🤝 Contribuciones

Si encuentras errores o tienes sugerencias de mejora, por favor:
1. Revisa la documentación existente
2. Verifica que el problema no esté ya documentado
3. Proporciona detalles específicos del problema

## 📄 Licencia

Esta guía es de uso educativo y puede ser utilizada libremente para fines de aprendizaje.

---

**¡Buena suerte con tu implementación de balanceador de carga!** 🚀

