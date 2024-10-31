#!/bin/bash

export OSMNS=rdsv

#bin/sdw-knf-consoles open $NSID1

#bin/sdw-knf-consoles open $NSID2

cd ~/shared/sdedge-ns/vnx

sudo vnx -f sdedge_nfv.xml --destroy

sudo vnx -f sdedge_nfv.xml -t

cd ~/shared/sdedge-ns/

./sdedge1.sh

./sdwan1.sh

./sdedge2.sh

./sdwan2.sh

./start_wg.sh

echo "Terminado"
