# OSManoVPN

### Escenario básico con Helm

En este caso se van a desplegar dos pods sobre Kubernetes usando Helm y conectarlos mediante OpenVPN:

- Desplegar los dos pods usando helm. Se debe ejecutar dos veces en la carpeta "/sd-edge/helm" ya que cada vez se instancia un solo pod:

	`cd helm`

	`helm install prueba cpechart/ --values cpechart/values.yaml`

- Para comprobar que todo se ha desplegado correctamente:

	`Kubectl get all`
	`kubectl get pods -o wide`

- Para conectar los pods con la red privada virtual se debe acceder a la shell de los contenedores con:

	`kubectl exec <nombrepod> -- /bin/bash`

	siendo <nombrepod> el nombre de los pods obtenido con el comando "kubectl get all"

	y acceder a la carpeta claves:

	`cd claves`

- Uno de los pods va a ser el server de OpenVPN. Para ello:

	`openvpn server.conf &`

- En el otro pod, cambiar en el archivo "client.conf" la palabra "serverContainerIP" por la IP del pod que hemos decidido que sea el server y que se obtiene con el comando "kubectl get pods -o wide" . Después ejecutar:

	`openvpn client.conf &`

- Comprobar conectividad con ping/traceroute/iperf entre las IPs de los pods.
