#!/bin/bash
export SDWNS  # needs to be defined in calling shell
export SIID="$NSID1" # $NSID1, for OSM, to be defined in calling shell

export NETNUM=1 # used to select external networks

export REMOTESITE="10.100.3.100" # used to establish a tunnel to a central sw

#export DSTP="4789"

#export WG0IP="10.100.169.1"

#export WG0IPREMOTESITE="10.100.169.2"

#export CONFIGMAP_LOCAL="cpe1-public-key"

# HELM SECTION
./k8s_sdwan_start.sh