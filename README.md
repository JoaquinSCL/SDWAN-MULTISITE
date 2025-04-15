
Repository for SD-WAN lab with k8s.
 
The lab manual, in Spanish, is [here](doc/rdsv-p4.md)

In this branch the tunnel between central offices has been replaced by a tunnel
between KNF-cpe-1 and bcg0.

It can be tested by executing the following commands:

```bash
bin/prepare-k8slab
source ~/.bashrc

sudo vnx -f vnx/sdedge_nfv.xml -t

./sdedge1.sh

./sdwan1.sh

./sdedge2.sh

./sdwan2.sh
```

Then, enter r1 and r2 consoles and ping r0

```bash
# from r1
ping 10.20.0.100
```

### **1. Despliegue básico del entorno con Helm**

El entorno incluye tres componentes principales:
- **Cliente**: Conectado a `extnet1`.
- **Servidor**: Conectado a `extnet1` y `extnet2`.
- **Pod de prueba (Test)**: Conectado a `extnet2`.

#### **Pasos para el despliegue**
1. Navegar al directorio que contiene los charts de Helm.
   ```bash
   cd helm
   ```

2. Desplegar los tres componentes utilizando los siguientes comandos:
   ```bash
   helm install server cpechart/ --values cpechart/values.yaml --set deployment.network="extnet1\,extnet2"
   helm install client cpechart/ --values cpechart/values.yaml --set deployment.network="extnet1"
   helm install test cpechart/ --values cpechart/values.yaml --set deployment.network="extnet2"
   ```

3. Verificar el estado del despliegue:
   ```bash
   kubectl get all
   kubectl get pods -o wide
   ```

4. Para acceder a los pods:
   ```bash
   kubectl exec -it <nombrepod> -- /bin/bash
   ```

5. Configurar las IPs de las interfaces de red externas (`extnet1` y `extnet2`):
   ```bash
   # En el servidor a extnet1
   ifconfig net1 10.100.1.1/24
   # En el cliente a extnet1
   ifconfig net1 10.100.1.2/24
   # En el pod de prueba a extnet2
   ifconfig net1 10.100.2.2/24
   ```

#### **Para eliminar los recursos**
   ```bash
   helm uninstall server
   helm uninstall client
   helm uninstall test
   ```

---

#### **Extensión a nivel 2 con GENEVE**
```bash
#Client
ip link add name geneve0 type geneve id 1000 remote 10.100.1.1
ip link set geneve0 up
ip addr add 10.100.3.8/24 dev geneve0 
#Server
ifconfig net2 10.100.2.1/24
ip link add name geneve0 type geneve id 1000 remote 10.100.1.2
ip link add name geneve1 type geneve id 1000 remote 10.100.2.2
ip link set geneve0 up
ip link set geneve1 up
ip link add name br0 type bridge
ip link set dev br0 up
ip link set geneve0 master br0
ip link set geneve1 master br0
ip addr add 10.100.3.1/24 dev br0
#Test
ip link add name geneve1 type geneve id 1000 remote 10.100.2.1
ip link set geneve1 up
ip addr add 10.100.3.2/24 dev geneve1
```

---

### **Verificación**
1. Probar conectividad bidireccional:
   ```bash
   ping 10.100.2.2
   ping 10.100.2.8
   ```
2. Monitorear tráfico:
   ```bash
   tcpdump -i wg0
   ```
