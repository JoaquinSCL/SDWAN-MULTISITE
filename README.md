# OSManoVPN

### Escenario básico con Helm

En este caso se van a desplegar tres pods sobre Kubernetes usando Helm y conectarlos mediante OpenVPN:

**Pasos previos para configurar las redes internas:**

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
**Pasos para desplegar el entorno:**

-  Desplegar tres helms diferentes uno conectado a extnet1(CLIENTE) otro conectado a extnet2(PRUEBA PING) y otro conectado a las dos(SERVER)

    `cd helm`
   
    ```yaml
    helm install server cpechartS/ --values cpechartS/values.yaml
    helm install client cpechartC/ --values cpechartC/values.yaml
    helm install test cpechartP/ --values cpechartP/values.yaml
    
    #para cerrar
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
    
- Hacer ping de client a prueba ping y usar tcpdump para comprobar si pasa por server el tráfico antes de desplegar la VPN
    
    ```yaml
    #en host
    "sudo ovs-ofctl show ExtNet1" y "sudo ovs-ofctl show ExtNet2" #para ver ombre de puertos
    sudo ovs-tcpdump -i [interfaz]
    #en los pods
    tcpdump -i [interfaz]
    ```
    
- Desplegar OpenVPN:
  
  	- Uno de los pods va a ser el server de OpenVPN. Para ello:

	```openvpn server.conf &```

	- En el otro pod, ejecutar.

	```openvpn client.conf &```
  
- Hacer ping de client a prueba ping y usar tcpdump para ver si pasa por server el tráfico
