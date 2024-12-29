#!/bin/bash

# Requires the following variables
# KUBECTL: kubectl command
# OSMNS: OSM namespace in the cluster vim
# NETNUM: used to select external networks
# VCPE: "pod_id" or "deploy/deployment_id" of the cpe vnf
# VWAN: "pod_id" or "deploy/deployment_id" of the wan vnf
# REMOTESITE: the "public" IP of the remote site
# WG0IP: the IP address of the wireguard interface in the cpe
# WG0IPREMOTESITE: the IP address of the wireguard interface in the remote site

KUBECTL="microk8s kubectl"
OSMNS="rdsv"

for NETNUM in {1..2}
do
    if [ "$NETNUM" == "1" ]; then
        CONFIGMAP_PEER="cpe2-public-key"
        REMOTESITE="10.100.2.1"
        WG0IP="10.100.169.1"
        WG0IPREMOTESITE="10.100.169.2"
        VCPE="deploy/cpe1-cpechart"
        CPE_EXEC="$KUBECTL exec -n $OSMNS $VCPE --"
        VWAN="deploy/wan$NETNUM-wanchart"
        WAN_EXEC="$KUBECTL exec -n $OSMNS $VWAN --"
        IPWAN=`$WAN_EXEC hostname -I | awk '{print $1}'`
        echo $IPWAN

    elif [ "$NETNUM" == "2" ]; then
        CONFIGMAP_PEER="cpe1-public-key"
        REMOTESITE="10.100.1.1"
        WG0IP="10.100.169.2"
        WG0IPREMOTESITE="10.100.169.1"
        VCPE="deploy/cpe2-cpechart"
        CPE_EXEC="$KUBECTL exec -n $OSMNS $VCPE --"
        VWAN="deploy/wan$NETNUM-wanchart"
        WAN_EXEC="$KUBECTL exec -n $OSMNS $VWAN --"
        IPWAN=`$WAN_EXEC hostname -I | awk '{print $1}'`
        echo $IPWAN
    fi
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
        else
            echo $peer_public_key
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

    $CPE_EXEC ovs-vsctl add-br brwan
    $CPE_EXEC ip link add cpewan type vxlan id 5 remote $IPWAN dev eth0 dstport 8741
    $CPE_EXEC ovs-vsctl add-port brwan cpewan
    $CPE_EXEC ifconfig cpewan up
    $CPE_EXEC ip link add sr1sr2 type vxlan id 12 local $WG0IP remote $WG0IPREMOTESITE dev wg0 dstport 4789
    $CPE_EXEC ifconfig sr1sr2 up
    $CPE_EXEC ovs-vsctl add-port brwan sr1sr2
done