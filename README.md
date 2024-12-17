# OSManoVPN

### Escenario básico con Helm

En este caso se van a desplegar tres pods sobre Kubernetes usando Helm y conectarlos mediante VPN de nivel 2. Se van a probar OpenVPN y WireGuard:

**Pasos comunes para configurar las redes internas:**

- Crear los virtual switch (Extnet1 y extnet2)
    
    ```
    sudo ovs-vsctl add-br ExtNet1
    sudo ovs-vsctl add-br ExtNet2
    ```
    
- Conectarlo al switch con “microk8s kubectl get -network-attachment-definitions extnet1” y con extnet2
    
    ```
    # Configure Multus extnet1
    microk8s kubectl get network-attachment-definitions extnet1 || \
    cat <<EOF | microk8s kubectl create -f -
    apiVersion: "k8s.cni.cncf.io/v1"
    kind: NetworkAttachmentDefinition
    metadata:
     name: extnet1
     annotations:
       k8s.v1.cni.cncf.io/resourceName: ovs-cni.network.kubevirt.io/ExtNet1
    spec:
     config: '{
       "cniVersion": "0.3.1",
       "type": "ovs",
       "bridge": "ExtNet1"
     }'
    EOF
    
    # Configure Multus extnet2
    microk8s kubectl get network-attachment-definitions extnet2 || \
    cat <<EOF | microk8s kubectl create -f -
    apiVersion: "k8s.cni.cncf.io/v1"
    kind: NetworkAttachmentDefinition
    metadata:
     name: extnet2
     annotations:
       k8s.v1.cni.cncf.io/resourceName: ovs-cni.network.kubevirt.io/ExtNet2
    spec:
     config: '{
       "cniVersion": "0.3.1",
       "type": "ovs",
       "bridge": "ExtNet2"
     }'
    EOF
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

### **2. Configuración de OpenVPN**

La configuración se basa en los archivos `server.conf` y `client.conf` que definen la operación del servidor y el cliente respectivamente.

#### **Servidor OpenVPN**
1. Iniciar el servicio:
   ```bash
   openvpn server.conf &
   ```

#### **Cliente OpenVPN**
1. Iniciar el cliente:
   ```bash
   openvpn client.conf &
   ```

#### **Prueba de conectividad**
1. Desde el cliente, probar conectividad con el pod de prueba:
   ```bash
   ping 10.100.2.2
   ping 10.100.2.8
   ```
2. Verificar tráfico en el servidor con `tcpdump`:
   ```bash
   tcpdump -i tap0
   ```
3. Opcionalmente:
   ```bash
   #en host
   "sudo ovs-ofctl show ExtNet1" y "sudo ovs-ofctl show ExtNet2" #para ver nombre de puertos
   sudo ovs-tcpdump -i [interfaz]
   ```
   
---

### **3. Configuración de WireGuard con soporte para nivel 2**

Wireguard solo permite crear túneles de nivel 3. Para poder convertir esta comunicación a nivel 2 tenemos varias opciones

#### **Túnel WireGuard**

Interfaz gretap conectado mediante un bridge a la interfaz de wireguard (wg0)
Podemos utilizar un tunel de tipo Gretap sobre el túnel de Wireguard. A continuación se exponen los pasos para hacerlo.

##### Servidor:
1. Crear claves privadas y públicas:
   ```bash
   wg genkey | tee wgkeyprivs | wg pubkey > wgkeypubs
   ```
2. Configurar la interfaz WireGuard:
   ```bash
   ip link add wg0 type wireguard
   wg set wg0 listen-port 1194 private-key ./wgkeyprivs
   ip address add 10.100.169.1/24 dev wg0
   ip link set dev wg0 mtu 1500
   ip link set wg0 up
   wg set wg0 peer <clavePublicaCliente> allowed-ips 0.0.0.0/0 endpoint 10.100.1.2:1194
   ```

##### Cliente:
1. Crear claves privadas y públicas:
   ```bash
   wg genkey | tee wgkeyprivs | wg pubkey > wgkeypubs
   ```
2. Configurar la interfaz WireGuard:
   ```bash
   ip link add wg0 type wireguard
   wg set wg0 listen-port 1194 private-key ./wgkeyprivs
   ip address add 10.100.169.2/24 dev wg0
   ip link set dev wg0 mtu 1500
   ip link set wg0 up
   wg set wg0 peer <clavePublicaServidor> allowed-ips 0.0.0.0/0 endpoint 10.100.1.1:1194
   ```

---

#### **Extensión a nivel 2**
##### Opción 1: GREtap
- **Servidor**:
  ```bash
  ip link add gretun type gretap local 10.100.169.1 remote 10.100.169.2 ignore-df nopmtudisc
  ip link set gretun up
  ip link add name br0 type bridge
  ip link set dev br0 up
  ip link set dev net2 master br0
  ip link set gretun master br0
  ip addr add 10.100.2.1/24 dev br0
  ```
- **Cliente**:
  ```bash
  ip link add gretun type gretap local 10.100.169.2 remote 10.100.169.1 ignore-df nopmtudisc
  ip link set gretun up
  ip addr add 10.100.2.8/24 dev gretun
  ```

##### Opción 2: VXLAN

En cada lado, crear interfaz VXLAN que encapsulara en paquetes de nivel dos la informacion transmitida.

- **Servidor**:
  ```bash
  ip link add vxlan0 type vxlan id 1000 local 10.100.169.1 remote 10.100.169.2 dev wg0 dstport 4789
  ip link set vxlan0 up
  ip link add name br0 type bridge
  ip link set dev br0 up
  ip link set dev net2 master br0
  ip link set vxlan0 master br0
  ip addr add 10.100.2.1/24 dev br0
  ```
- **Cliente**:
  ```bash
  ip link add vxlan0 type vxlan id 1000 local 10.100.169.2 remote 10.100.169.1 dev wg0 dstport 4789
  ip link set vxlan0 up
  ip addr add 10.100.2.8/24 dev vxlan0
  ```

---

### **4. Verificación**
1. Probar conectividad bidireccional:
   ```bash
   ping 10.100.2.2
   ping 10.100.2.8
   ```
2. Monitorear tráfico:
   ```bash
   tcpdump -i wg0
   ```

