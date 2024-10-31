#!/bin/bash
  
# Requires the following variables
# OSMNS: OSM namespace in the cluster vim
# SIID: id of the service instance
# NETNUM: used to select external networks
# REMOTESITE: the public IP of the remote site vCPE

set -u # to verify variables are defined
: $OSMNS
: $SIID
: $NETNUM
: $REMOTESITE
: $WG0IP
: $WG0IPREMOTESITE

export KUBECTL="microk8s kubectl"

deployment_id() {
    echo `osm ns-show $1 | grep kdu-instance | grep $2 | awk -F':' '{gsub(/[", |]/, "", $2); print $2}' `
}

## 0. Obtener deployment ids de las vnfs
echo "## 0. Obtener deployment ids de las vnfs"
OSMACC=$(deployment_id $SIID "access")
OSMCPE=$(deployment_id $SIID "cpe")
OSMWAN=$(deployment_id $SIID "wan")
#OSMCTRL=$(deployment_id $SIID "wan")

OSMWAN=$(echo "$OSMWAN" | cut -d ' ' -f1)
#OSMCTRL=$(echo "$OSMCTRL" | cut -d ' ' -f2)

echo "--OSMWAN: $OSMWAN"
#echo "--OSMCTRL: $OSMCTRL"

export VACC="deploy/$OSMACC"
export VCPE="deploy/$OSMCPE"
export VWAN="deploy/$OSMWAN"
#export VCTRL="deploy/$OSMCTRL"

#./start_sdctrl_dev.sh
#./start_sdwan_dev.sh

./start_sdwan.sh