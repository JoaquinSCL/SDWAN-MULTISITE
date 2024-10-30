#!/bin/bash

set -u # to verify variables are defined
: $OSMNS

# HELM SECTION
for NETNUM in {1..2}
do
  for VNF in access cpe wan
  do
    helm -n $OSMNS uninstall $VNF$NETNUM 
  done
done