#!/bin/bash

# Requires the following variables
# KUBECTL: kubectl command
# SDWNS: cluster namespace in the cluster vim
# NETNUM: used to select external networks
# VCPE: "pod_id" or "deploy/deployment_id" of the cpd vnf
# VWAN: "pod_id" or "deploy/deployment_id" of the wan vnf
# REMOTESITE: the "public" IP of the remote site
# WG0IP: the IP address of the wireguard interface in the cpe
# WG0IPREMOTESITE: the IP address of the wireguard interface in the remote site
# DSTP: the destination port for the vxlan tunnel

set -u # to verify variables are defined
: $KUBECTL
: $SDWNS
: $NETNUM
: $VCPE
: $VWAN
: $REMOTESITE
#: $WG0IP
#: $WG0IPREMOTESITE
#: $CONFIGMAP_LOCAL
#: $DSTP


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

CPE_EXEC="$KUBECTL exec -n $SDWNS $VCPE --"
WAN_EXEC="$KUBECTL exec -n $SDWNS $VWAN --"
WAN_SERV="${VWAN/deploy\//}"

# Router por defecto inicial en k8s (calico)
K8SGW="169.254.1.1"

## 1. Obtener IPs y puertos de las VNFs
echo "## 1. Obtener IPs y puertos de las VNFs"

IPCPE=`$CPE_EXEC hostname -I | awk '{print $1}'`
echo "IPCPE = $IPCPE"

IPWAN=`$WAN_EXEC hostname -I | awk '{print $1}'`
echo "IPWAN = $IPWAN"

PORTWAN=`$KUBECTL get -n $SDWNS -o jsonpath="{.spec.ports[0].nodePort}" service $WAN_SERV`
echo "PORTWAN = $PORTWAN"

## 2. En VNF:cpe agregar un bridge y sus vxlan
echo "## 2. En VNF:cpe agregar un bridge y configurar IPs y rutas"

#$CPE_EXEC sh -c "wg genkey | tee wgkeyprivs | wg pubkey > wgkeypubs"
#public_key=$($CPE_EXEC cat wgkeypubs)
#$KUBECTL patch configmap $CONFIGMAP_LOCAL -n $OSMNS -p "{\"data\":{\"publicKey\":\"$public_key\"}}"

echo " netnum = $NETNUM"
#echo " dstp = $DSTP"
echo " ipIF = 10.100.$NETNUM.1"

$CPE_EXEC ip route add $IPWAN/32 via $K8SGW
$CPE_EXEC ovs-vsctl add-br brwan
$CPE_EXEC ip link add cpewan type vxlan id 5 remote $IPWAN dstport 8741 dev eth0
$CPE_EXEC ovs-vsctl add-port brwan cpewan
$CPE_EXEC ifconfig cpewan up
#$CPE_EXEC ip link add sr1sr2 type vxlan id 12 local $WG0IP remote $WG0IPREMOTESITE dev wg0 dstport 4789
$CPE_EXEC ip link add sr1sr2$NETNUM type vxlan id 1$NETNUM remote $REMOTESITE dstport 4789 dev net$NETNUM
$CPE_EXEC ovs-vsctl add-port brwan sr1sr2$NETNUM
$CPE_EXEC ifconfig sr1sr2$NETNUM up

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