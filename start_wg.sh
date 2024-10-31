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

export KUBECTL="microk8s kubectl"
export OSMNS="rdsv"

for NETNUM in {1..2}
do
    if [ "$NETNUM" == "1" ]; then
        CONFIGMAP_PEER="cpe2-public-key"
        REMOTESITE="10.100.2.1"
        WG0IP="10.100.169.1"
        WG0IPREMOTESITE="10.100.169.2"
        VCPE="deploy/cpe1-cpechart"
        CPE_EXEC="$KUBECTL exec -n $OSMNS $VCPE --"
    elif [ "$NETNUM" == "2" ]; then
        CONFIGMAP_PEER="cpe1-public-key"
        REMOTESITE="10.100.1.1"
        WG0IP="10.100.169.2"
        WG0IPREMOTESITE="10.100.169.1"
        VCPE="deploy/cpe2-cpechart"
        CPE_EXEC="$KUBECTL exec -n $OSMNS $VCPE --"
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

    $CPE_EXEC ip link add sr1sr2 type vxlan id 12 local $WG0IP remote $WG0IPREMOTESITE dstport 8742 dev wg0
    $CPE_EXEC ovs-vsctl add-port brwan sr1sr2
    $CPE_EXEC ifconfig sr1sr2 up
done