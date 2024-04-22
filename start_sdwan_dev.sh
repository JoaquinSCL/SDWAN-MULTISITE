#!/bin/bash

# Requires the following variables
# KUBECTL: kubectl command
# OSMNS: OSM namespace in the cluster vim
# NETNUM: used to select external networks
# VCPE: "pod_id" or "deploy/deployment_id" of the cpd vnf
# VWAN: "pod_id" or "deploy/deployment_id" of the wan vnf
# REMOTESITE: the "public" IP of the remote site

set -u # to verify variables are defined
: $KUBECTL
: $OSMNS
: $NETNUM
: $VCPE
: $VACC
: $VCTRL
: $VWAN
: $REMOTESITE

if [[ ! $VCPE =~ "sdedge-ns-repo-cpechart"  ]]; then
    echo ""       
    echo "ERROR: incorrect <cpe_deployment_id>: $VCPE"
    exit 1
fi

if [[ ! $VWAN =~ "sdedge-ns-repo-wanchart"  ]]; then
    echo ""       
    echo "ERROR: incorrect <wan_deployment_id>: $VWAN"
    exit 1
fi

if [[ ! $VACC =~ "sdedge-ns-repo-accesschart"  ]]; then
    echo ""       
    echo "ERROR: incorrect <access_deployment_id>: $VACC"
    exit 1
fi

if [[ ! $VCTRL =~ "sdedge-ns-repo-wanchart"  ]]; then
    echo ""       
    echo "ERROR: incorrect <wan_deployment_id>: $VCTRL"
    exit 1
fi

CPE_EXEC="$KUBECTL exec -n $OSMNS $VCPE --"
CPE_SERV="${VCPE/deploy\//}"
ACC_EXEC="$KUBECTL exec -n $OSMNS $VACC --"
ACC_SERV="${VACC/deploy\//}"
WAN_EXEC="$KUBECTL exec -n $OSMNS $VWAN --"
WAN_SERV="${VWAN/deploy\//}"
CTRL_EXEC="$KUBECTL exec -n $OSMNS $VCTRL --"
CTRL_SERV="${VCTRL/deploy\//}"

# Router por defecto inicial en k8s (calico)
K8SGW="169.254.1.1"

## 1. Obtener IPs y puertos de las VNFs
echo "## 1. Obtener IPs y puertos de las VNFs"

IPCPE=`$CPE_EXEC hostname -I | awk '{print $1}'`
echo "IPCPE = $IPCPE"

IPWAN=`$WAN_EXEC hostname -I | awk '{print $1}'`
echo "IPWAN = $IPWAN"

IPCTRL=`$CTRL_EXEC hostname -I | awk '{print $1}'`
echo "IPCTRL = $IPCTRL"

PORTCTRL=`$KUBECTL get -n $OSMNS -o jsonpath="{.spec.ports[0].nodePort}" service $CTRL_SERV`
echo "PORTCTRL = $PORTCTRL"

## 2. En VNF:cpe agregar un bridge y sus vxlan
echo "## 2. En VNF:cpe agregar un bridge y configurar IPs y rutas"
$CPE_EXEC ip route add $IPWAN/32 via $K8SGW
$CPE_EXEC ip route add $IPCTRL/32 via $K8SGW
$CPE_EXEC ovs-vsctl add-br brwan
$CPE_EXEC ip link add cpewan type vxlan id 5 remote $IPWAN dstport 8741 dev eth0
$CPE_EXEC ovs-vsctl add-port brwan cpewan
$CPE_EXEC ifconfig cpewan up
$CPE_EXEC ip link add sr1sr2 type vxlan id 12 remote $REMOTESITE dstport 8742 dev net$NETNUM
$CPE_EXEC ovs-vsctl add-port brwan sr1sr2
$CPE_EXEC ifconfig sr1sr2 up

## 3. En VNF:wan activar el modo SDN del conmutador y crear vxlans
echo "## 3. En VNF:wan activar el modo SDN del conmutador y crear vxlans"

$WAN_EXEC ovs-vsctl set bridge brwan protocols=OpenFlow10,OpenFlow12,OpenFlow13
$WAN_EXEC ovs-vsctl set-fail-mode brwan secure
$WAN_EXEC ovs-vsctl set bridge brwan other-config:datapath-id=0000000000000001
$WAN_EXEC ovs-vsctl set-controller brwan tcp:$IPCTRL:6633

$WAN_EXEC ip link add cpewan type vxlan id 5 remote $IPCPE dstport 8741 dev eth0
$WAN_EXEC ovs-vsctl add-port brwan cpewan
$WAN_EXEC ifconfig cpewan up

## 4. En VNF:access activar el modo SDN del conmutador
echo "## 4. En VNF:access activar el modo SDN del conmutador"

$ACC_EXEC ovs-vsctl set bridge brwan protocols=OpenFlow10,OpenFlow12,OpenFlow13
$ACC_EXEC ovs-vsctl set-fail-mode brwan secure
$ACC_EXEC ovs-vsctl set bridge brwan other-config:datapath-id=0000000000000002
$ACC_EXEC ovs-vsctl set-controller brwan tcp:$IPCTRL:6633

## 5. En VNF:cpe activar el modo SDN del conmutador
echo "## 5. En VNF:cpe activar el modo SDN del conmutador"

$CPE_EXEC ovs-vsctl set bridge brwan protocols=OpenFlow10,OpenFlow12,OpenFlow13
$CPE_EXEC ovs-vsctl set-fail-mode brwan secure
$CPE_EXEC ovs-vsctl set bridge brwan other-config:datapath-id=0000000000000003
$CPE_EXEC ovs-vsctl set-controller brwan tcp:$IPCTRL:6633

## 6. Aplica las reglas de la sdwan con ryu
echo "## 6. Aplica las reglas de la sdwan con ryu"
RYU_ADD_URL="http://localhost:$PORTCTRL/stats/flowentry/add"
curl -X POST -d @json/from-cpe-WAN.json $RYU_ADD_URL
curl -X POST -d @json/to-cpe-WAN.json $RYU_ADD_URL
curl -X POST -d @json/broadcast-from-axs-WAN.json $RYU_ADD_URL
curl -X POST -d @json/from-mpls-WAN.json $RYU_ADD_URL
curl -X POST -d @json/to-voip-gw-WAN.json $RYU_ADD_URL
curl -X POST -d @json/sdedge$NETNUM/to-voip.json $RYU_ADD_URL

curl -X POST -d @json/broadcast-from-wan-CPE.json $RYU_ADD_URL
curl -X POST -d @json/from-sr1sr2-CPE.json $RYU_ADD_URL
curl -X POST -d @json/from-wan-CPE.json $RYU_ADD_URL

curl -X POST -d @json/broadcast-from-vxlan1-ACC.json $RYU_ADD_URL
curl -X POST -d @json/from-vxlan1-ACC.json $RYU_ADD_URL
curl -X POST -d @json/from-wan-ACC.json $RYU_ADD_URL

## 7. Aplica las reglas de qos
echo "## 7. Aplica las reglas de qos"
$WAN_EXEC ovs-vsctl set-manager ptcp:6632
curl -X PUT -d "\"tcp:$IPWAN:6632\"" http://localhost:$PORTCTRL/v1.0/conf/switches/0000000000000001/ovsdb_addr
curl -X POST -d '{"port_name": "net1", "type": "linux-htb", "max_rate":"2800000", "queues": [{"max_rate":"2800000"}, {"min_rate": "800000"}]}' http://localhost:$PORTCTRL/qos/queue/0000000000000001
curl -X POST -d '{"match": {"nw_dst": "10.20.1.2", "nw_proto": "UDP", "udp_dst": "5005"}, "actions":{"queue": "1"}}' http://localhost:$PORTCTRL/qos/rules/0000000000000001
curl -X POST -d '{"match": {"nw_dst": "10.20.2.2", "nw_proto": "UDP", "udp_dst": "5005"}, "actions":{"queue": "1"}}' http://localhost:$PORTCTRL/qos/rules/0000000000000001
curl -X GET http://localhost:$PORTCTRL/qos/rules/0000000000000001

echo "--"
echo "sdwan$NETNUM: abrir navegador para ver sus flujos Openflow:"
echo "firefox http://localhost:$PORTCTRL/home/ &"
