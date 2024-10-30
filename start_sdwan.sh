#!/bin/bash

# Requires the following variables
# KUBECTL: kubectl command
# OSMNS: OSM namespace in the cluster vim
# NETNUM: used to select external networks
# VCPE: "pod_id" or "deploy/deployment_id" of the cpe vnf
# VWAN: "pod_id" or "deploy/deployment_id" of the wan vnf
# REMOTESITE: the "public" IP of the remote site
# VCPE_ID: either "cpe1" or "cpe2" to distinguish the deployment
# WG0IP: the IP address of the wireguard interface in the cpe
# WG0IPREMOTESITE: the IP address of the wireguard interface in the remote site
# REMOTENETNUM: the NETNUM of the remote site


set -u # to verify variables are defined
: $KUBECTL
: $OSMNS
: $NETNUM
: $VCPE
: $VWAN
: $REMOTESITE
: $VCPE_ID
: $WG0IP
: $WG0IPREMOTESITE
: $REMOTENETNUM

if [[ ! $VCPE =~ "-cpechart"  ]]; then
    echo ""       
    echo "ERROR: incorrect <cpe_deployment_id>: $VCPE"
    exit 1
fi

if [[ ! $VWAN =~ "-wanchart"  ]]; then
   echo ""       
   echo "ERROR: incorrect <wan_deployment_id>: $VWAN"
   exit 1
fi

if [ "$VCPE_ID" == "cpe1" ]; then
    CONFIGMAP_LOCAL="cpe1-public-key"
    CONFIGMAP_PEER="cpe2-public-key"
elif [ "$VCPE_ID" == "cpe2" ]; then
    CONFIGMAP_LOCAL="cpe2-public-key"
    CONFIGMAP_PEER="cpe1-public-key"
else
    echo "ERROR: Unknown VCPE_ID '$VCPE_ID'. Expected 'cpe1' or 'cpe2'."
    exit 1
fi

CPE_EXEC="$KUBECTL exec -n $OSMNS $VCPE --"
WAN_EXEC="$KUBECTL exec -n $OSMNS $VWAN --"
WAN_SERV="${VWAN/deploy\//}"

# Router por defecto inicial en k8s (calico)
K8SGW="169.254.1.1"

## 1. Obtener IPs y puertos de las VNFs
echo "## 1. Obtener IPs y puertos de las VNFs"

IPCPE=`$CPE_EXEC hostname -I | awk '{print $1}'`
echo "IPCPE = $IPCPE"

IPWAN=`$WAN_EXEC hostname -I | awk '{print $1}'`
echo "IPWAN = $IPWAN"

PORTWAN=`$KUBECTL get -n $OSMNS -o jsonpath="{.spec.ports[0].nodePort}" service $WAN_SERV`
echo "PORTWAN = $PORTWAN"

## 2. En VNF:cpe agregar instancia wireguard, bridge y sus vxlans
echo "## 2. En VNF:cpe agregar un bridge y configurar IPs y rutas"

$CPE_EXEC sh -c "wg genkey | tee wgkeyprivs | wg pubkey > wgkeypubs"
public_key=$($CPE_EXEC cat wgkeypubs)
$KUBECTL patch configmap $CONFIGMAP_LOCAL -n $OSMNS -p "{\"data\":{\"publicKey\":\"$public_key\"}}"
# Esperar hasta que la clave pública del peer esté disponible
echo "Esperando a que la clave pública del peer ($CONFIGMAP_PEER) esté disponible..."
peer_public_key=""
attempt=0
max_attempts=10
while [ -z "$peer_public_key" ] && [ $attempt -lt $max_attempts ]; do
    peer_public_key=$($KUBECTL get configmap $CONFIGMAP_PEER -n $OSMNS -o jsonpath='{.data.publicKey}' 2>/dev/null || echo "")
    if [ -z "$peer_public_key" ]; then
        echo "Intento $((attempt + 1))/$max_attempts: La clave pública del peer aún no está disponible. Esperando 5 segundos..."
        sleep 5
        attempt=$((attempt + 1))
    fi
done

if [ -z "$peer_public_key" ]; then
    echo "ERROR: No se pudo obtener la clave pública del peer después de $max_attempts intentos."
    exit 1
fi

$CPE_EXEC ip link add wg0 type wireguard
$CPE_EXEC wg set wg0 listen-port 1194 private-key ./wgkeyprivs
$CPE_EXEC ip address add $WG0IP/24 dev wg0
$CPE_EXEC ip link set dev wg0 mtu 1500
$CPE_EXEC ip link set wg0 up
$CPE_EXEC wg set wg0 peer $peer_public_key allowed-ips 0.0.0.0/0 endpoint $REMOTESITE:1194

$CPE_EXEC ip route add $IPWAN/32 via $K8SGW
$CPE_EXEC ovs-vsctl add-br brwan
$CPE_EXEC ip link add cpewan type vxlan id 5 remote $IPWAN dstport 8741 dev eth0
$CPE_EXEC ovs-vsctl add-port brwan cpewan
$CPE_EXEC ifconfig cpewan up
$CPE_EXEC ip link add sr1sr2 type vxlan id 12 local $WG0IP remote $WG0IPREMOTESITE dstport 8742 dev wg0
$CPE_EXEC ovs-vsctl add-port brwan sr1sr2
$CPE_EXEC ifconfig sr1sr2 up

## 3. En VNF:wan arrancar controlador SDN"
echo "## 3. En VNF:wan arrancar controlador SDN"
#$WAN_EXEC /usr/local/bin/ryu-manager --verbose flowmanager/flowmanager.py ryu.app.ofctl_rest 2>&1 | tee ryu.log &
#$WAN_EXEC /usr/local/bin/ryu-manager ryu.app.simple_switch_13 ryu.app.ofctl_rest 2>&1 | tee ryu.log &
$WAN_EXEC /usr/local/bin/ryu-manager flowmanager/flowmanager.py ryu.app.ofctl_rest 2>&1 | tee ryu.log &

## 4. En VNF:wan activar el modo SDN del conmutador y crear vxlan
echo "## 4. En VNF:wan activar el modo SDN del conmutador y crear vxlan"

$WAN_EXEC ovs-vsctl set bridge brwan protocols=OpenFlow10,OpenFlow12,OpenFlow13
$WAN_EXEC ovs-vsctl set-fail-mode brwan secure
$WAN_EXEC ovs-vsctl set bridge brwan other-config:datapath-id=0000000000000001
$WAN_EXEC ovs-vsctl set-controller brwan tcp:127.0.0.1:6633

$WAN_EXEC ip link add cpewan type vxlan id 5 remote $IPCPE dstport 8741 dev eth0
$WAN_EXEC ovs-vsctl add-port brwan cpewan
$WAN_EXEC ifconfig cpewan up

## 5. Aplica las reglas de la sdwan con ryu
echo "## 5. Aplica las reglas de la sdwan con ryu"
RYU_ADD_URL="http://localhost:$PORTWAN/stats/flowentry/add"
curl -X POST -d @json/from-cpe.json $RYU_ADD_URL
curl -X POST -d @json/to-cpe.json $RYU_ADD_URL
curl -X POST -d @json/broadcast-from-axs.json $RYU_ADD_URL
curl -X POST -d @json/from-mpls.json $RYU_ADD_URL
curl -X POST -d @json/to-voip-gw.json $RYU_ADD_URL
curl -X POST -d @json/sdedge$NETNUM/to-voip.json $RYU_ADD_URL

echo "--"
echo "sdedge$NETNUM: abrir navegador para ver sus flujos Openflow:"
echo "firefox http://localhost:$PORTWAN/home/ &"