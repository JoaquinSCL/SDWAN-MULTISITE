#!/bin/bash
  
# Requires the following variables
# OSMNS:  namespace in the cluster vim
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

for vnf in access cpe
do
  helm -n $OSMNS uninstall $vnf$NETNUM 
done

helm -n $OSMNS uninstall cpe-public-keys

sleep 15

chart_suffix="chart-0.1.0.tgz"
for vnf in access cpe
do
  helm -n $OSMNS install $vnf$NETNUM $vnf$chart_suffix
done

sleep 10

export VACC="deploy/access$NETNUM-accesschart"
export VCPE="deploy/cpe$NETNUM-cpechart"

./start_corpcpe.sh

echo "--"
echo "K8s deployments para la red $NETNUM:"
echo $VACC
echo $VCPE
