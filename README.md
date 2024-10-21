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
**Pasos comunes para desplegar el entorno:**

-  Desplegar tres helms diferentes uno conectado a extnet1(CLIENTE) otro conectado a extnet2(PRUEBA PING) y otro conectado a las dos(SERVER)

    `cd helm`
   
    ```yaml
    helm install configmap cpe-public-keys --values cpe-public-keys/values.yaml
    helm install server cpechartS/ --values cpechartS/values.yaml
    helm install client cpechartC/ --values cpechartC/values.yaml
    helm install test cpechartP/ --values cpechartP/values.yaml
    
    #para cerrar
    helm uninstall configmap
    helm uninstall server
    helm uninstall client
    helm uninstall test
    
    ```

- Para comprobar que todo se ha desplegado correctamente:

	`Kubectl get all`
	`kubectl get pods -o wide`

- Para conectar los pods con la red privada virtual se debe acceder a la shell de los contenedores con:

	`kubectl exec <nombrepod> -- /bin/bash`

	siendo <nombrepod> el nombre de los pods obtenido con el comando "kubectl get all"

	y acceder a la carpeta claves:

	`cd claves`
    
- Darle IPs a  extnet1 y extnet2
    
    ```yaml
    ifconfig net1 10.100.1.1/24 #server a extnet1
    ifconfig net1 10.100.1.2/24 #client a extnet1
    ifconfig net1 10.100.2.2/24 #prueba a extnet2
    ```

- Si se quiere tener conectividad completa sin usar VPN, ejecutar el script "up" en el servidor, dentro de la carpeta /claves. Este script crea un brige y una interfaz (net2) en dicho bridge que conecta extnet2 a la interfaz net1 (y por tanto a extnet1). No ejecutar (o eliminar bridge) si posteriormente se quiere usar una de las soluciones VPN.
    
    ```yaml
    cd claves
    ./up br0 net2 net1 10.100.2.1 255.255.255.0 1200
    ```
    
- Si se ha ejecutado el script "up", hacer ping de client a prueba ping y usar tcpdump para comprobar si pasa por server el tráfico antes de desplegar la VPN
    
    ```yaml
    #en host
    "sudo ovs-ofctl show ExtNet1" y "sudo ovs-ofctl show ExtNet2" #para ver nombre de puertos
    sudo ovs-tcpdump -i [interfaz]
    #en los pods
    tcpdump -i [interfaz]
    ```

**Despliegue VPN:** 

- **Desplegar OpenVPN:**
  Toda la configuración, tanto de servidor como de cliente, está definida en los archivos de configuracion "server.conf" y "client.conf" respectivamente.
  
  	- Uno de los pods va a ser el server de OpenVPN. Para ello:

	```openvpn server.conf &```

	- En el otro pod, ejecutar.

	```openvpn client.conf &```

    - **Prueba conectividad:**
		- Hacer ping de client a prueba ping y viceversa:
	
	 	`ping 10.100.2.2`
	  	`ping 10.100.2.8`
	  
	 	- Usar tcpdump en el servidor para ver si pasa por ahí el tráfico:
	
	    	`tcpdump -i tap0`

		-Opcionalmente:

  		```yaml
		  #en host
		  "sudo ovs-ofctl show ExtNet1" y "sudo ovs-ofctl show ExtNet2" #para ver nombre de puertos
		  sudo ovs-tcpdump -i [interfaz]
		```

- **Desplegar Wireguard:**

  Wireguard solo permite crear túneles de nivel 3. Para poder convertir esta comunicación a nivel 2 tenemos varias opciones

 	- **Interfaz gretap conectado mediante un bridge a la interfaz de wireguard (wg0)**

   Podemos utilizar un tunel de tipo Gretap sobre el túnel de Wireguard. A continuación se exponen los pasos para hacerlo.

  	**Servidor:**

		**Creación túnel WireGuard (interfaz wg0)**
	
		```
		wg genkey | tee wgkeyprivs | wg pubkey > wgkeypubs
	
		ip link add wg0 type wireguard
	
		wg set wg0 listen-port 1194 private-key ./wgkeyprivs
	
		ip address add 10.100.169.1/24 dev wg0
	
		ip link set dev wg0 mtu 1500
	
		ip link set wg0 up
	
		wg set wg0 peer clavePubOtroPeer allowed-ips 0.0.0.0/0 endpoint 10.100.1.2:1194
	  	```
	
		**Creación túnel de tipo Gretap**
	
		```
	  	ip link add gretun type gretap local 10.100.169.1 remote 10.100.169.2 ignore-df nopmtudisc
	
		ip link set gretun up
		```
	
		**Creación interfaz bridge br0 y conectar net2 y gretap**
	
		```
	  	ip link add name br0 type bridge
	
		ip link set dev br0 up
		
		ip link set dev net2 master br0
		
		ip link set gretun master br0
		
		ip addr add 10.100.2.1/24 dev br0
	  
	  	brctl show
	  	```
		
  	**Cliente:**

	  	**Creación túnel WireGuard (interfaz wg0)**
		
		```
	  	wg genkey | tee wgkeyprivs | wg pubkey > wgkeypubs
		
		ip link add wg0 type wireguard
		
		wg set wg0 listen-port 1194 private-key ./wgkeyprivs
		
		ip address add 10.100.169.2/24 dev wg0
		
		ip link set dev wg0 mtu 1500
		
		ip link set wg0 up
		
		wg set wg0 peer clavePubOtroPeer allowed-ips 0.0.0.0/0 endpoint 10.100.1.1:1194
	 	```
		
	  	**Crear túnel de tipo Gretap**
		
	  	```
	   	ip link add gretun type gretap local 10.100.169.2 remote 10.100.169.1 ignore-df nopmtudisc
		
	  	ip link set gretun up
		
		ip addr add  10.100.2.8/24 dev gretun
		```
   
  	- **VXLAN sobre tunel wireguard**
        
	        En cada lado, crear interfaz VXLAN que encapsulara en paquetes de nivel dos la informacion transmitida.
	        
	        **En Server:**
	        
	        ```
	        ip link add vxlan0 type vxlan id 1000 local 10.100.169.1 remote 10.100.169.2 dev wg0 dstport 4789
	        ip link set vxlan0 up
	        
	        ```
	        
	        **En Cliente:**
	        
	        ```
	        ip link add vxlan0 type vxlan id 1000 local 10.100.169.2 remote 10.100.169.1 dev wg0 dstport 4789
	        ip link set vxlan0 up
	        ip addr add 10.100.2.8/24 dev vxlan0
	        
	        ```
	        
	     **Creación interfaz bridge br0 y conectar net2 y vxlan0**
	        
	        **En Server:**
	
		```
	 	ip link add name br0 type bridge
		ip link set dev br0 up
		ip link set dev net2 master br0
		ip link set vxlan0 master br0
		ip addr add 10.100.2.1/24 dev br0
	 	```
  
   - **Prueba conectividad:**
		
		- Comprobar interfaces wireguard
 		
   		```
		wg show  #en server y cliente
		```
     
  		- Hacer ping de client a prueba ping y viceversa:
	
	 	`ping 10.100.2.2`
	  	`ping 10.100.2.8`
	  
	 	- Usar tcpdump en el servidor para ver si pasa por ahí el tráfico:
	
	    	`tcpdump -i wg0`
