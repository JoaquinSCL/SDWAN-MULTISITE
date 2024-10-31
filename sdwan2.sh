#!/bin/bash
export OSMNS  # needs to be defined in calling shell
export SIID="$NSID2" # $NSID1 needs to be defined in calling shell

export NETNUM=2 # used to select external networks

export REMOTESITE="10.100.1.1"

export WG0IP="10.100.169.2"

export WG0IPREMOTESITE="10.100.169.1"

export CONFIGMAP_LOCAL="cpe2-public-key"

# OSM SECTION
#./osm_sdwan_start.sh

# HELM SECTION
./k8s_sdwan_start.sh
