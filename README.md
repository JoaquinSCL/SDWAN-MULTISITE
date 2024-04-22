OSManoVPN

- Desplegar 2 helms con helm install prueba cpechart/ --values cpechart/values.yaml x2 en sd-edge/helm
  
- Kubectl get all y kubectl get pods -o wide
- kubectl exec nombrepod -- /bin/bash x2
- En uno de ellos ejecutar openvpn server.conf & sin cambiar nada
- En el otro cambiar client.conf serverContainerIP por la IP del server que esta en comando kubectl get pods -o wide y luego ejecutar openvpn client.conf &
