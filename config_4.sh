#!/bin/bash

echo "Configuración final"

bin/sdw-knf-consoles open $NSID1

bin/sdw-knf-consoles open $NSID2

./sdedge1.sh

./sdwan1.sh

./sdedge2.sh

./sdwan2.sh

echo "Terminado"
