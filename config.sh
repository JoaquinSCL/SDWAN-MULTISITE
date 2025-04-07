#!/bin/bash

bin/prepare-k8slab

source ~/.bashrc

sudo vnx -f vnx/sdedge_nfv.xml -P

sudo vnx -f vnx/sdedge_nfv.xml -t

./sdedge1.sh

./sdwan1.sh

./sdedge2.sh

./sdwan2.sh

#./start_wg.sh

echo "Terminado"
