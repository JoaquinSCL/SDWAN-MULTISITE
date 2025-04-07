#!/bin/bash
export SDWNS  # needs to be defined in calling shell
export SIID="$NSID2" # $NSID2, for OSM, to be defined in calling shell

export NETNUM=2 # used to select external networks

export REMOTESITE="10.100.3.100" # used to establish a tunnel to a central sw

#export DSTP="8742"

#export WG0IP="10.100.169.2"

#export WG0IPREMOTESITE="10.100.169.1"

#export CONFIGMAP_LOCAL="cpe2-public-key"

# HELM SECTION
./k8s_sdwan_start.sh