#!/bin/bash

export OSMNS=rdsv

cd ~/shared/sdedge-ns/vnx

sudo vnx -f sdedge_nfv.xml --destroy

cd ~/shared/sdedge-ns/

# HELM SECTION
for NETNUM in {1..2}
do
  for VNF in access cpe wan
  do
    helm -n $OSMNS uninstall $VNF$NETNUM 
  done
done

helm -n $OSMNS uninstall cpe-public-keys

sleep 120

./config.sh