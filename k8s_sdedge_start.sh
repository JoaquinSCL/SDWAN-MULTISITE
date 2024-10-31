#!/bin/bash
  
# Requires the following variables
# OSMNS: OSM namespace in the cluster vim
# NETNUM: used to select external networks
# CUSTUNIP: the ip address for the customer side of the tunnel
# VNFTUNIP: the ip address for the vnf side of the tunnel
# VCPEPUBIP: the public ip address for the vcpe
# VCPEGW: the default gateway for the vcpe

set -u # to verify variables are defined
: $OSMNS
: $NETNUM
: $CUSTUNIP
: $VNFTUNIP
: $VCPEPUBIP
: $VCPEGW

export KUBECTL="microk8s kubectl"

## 0. Instalación
echo "## 0. Instalación de las vnfs"

for vnf in access cpe wan
do
  helm -n $OSMNS uninstall $vnf$NETNUM 
done

if [ $NETNUM == "1" ]; then
  helm -n $OSMNS uninstall cpe-public-keys
else
  echo ""
fi

sleep 15

chart_suffix="chart-0.1.0.tgz"
configmap_chart_suffix="-0.1.0.tgz"

if [ $NETNUM == "1" ]; then
  helm -n $OSMNS install cpe-public-keys cpe-public-keys$configmap_chart_suffix
else
  echo "ConfigMap de claves públicas ya instalado"
fi

for vnf in access cpe wan
do
  helm -n $OSMNS install $vnf$NETNUM $vnf$chart_suffix
done

sleep 10

export VACC="deploy/access$NETNUM-accesschart"
export VCPE="deploy/cpe$NETNUM-cpechart"
export VWAN="deploy/wan$NETNUM-wanchart"

./start_corpcpe.sh
./start_sdedge.sh

echo "--"
echo "$(basename "$0")"
echo "K8s deployments para la red $NETNUM:"
echo $VACC
echo $VCPE
echo $VWAN
