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
: $CONFIGMAP_LOCAL

export KUBECTL="microk8s kubectl"

export VACC="deploy/access$NETNUM-accesschart"
export VCPE="deploy/cpe$NETNUM-cpechart"
export VWAN="deploy/wan$NETNUM-wanchart"

./start_sdwan.sh

