#!/bin/bash
export OSMNS  # needs to be defined in calling shell
export SIID="$NSID2" # $NSID1 needs to be defined in calling shell

export NETNUM=2 # used to select external networks

export REMOTESITE="10.100.1.1"

./osm_sdwan_start.sh
