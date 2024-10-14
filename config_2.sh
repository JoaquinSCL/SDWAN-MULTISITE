
#!/bin/bash

cd bin

osm ns-delete --force sdedge1

osm ns-delete --force sdedge2

echo "Empieza el sleep"
sleep 20
echo "Termina el sleep"

./rdsv-config-osmlab S

echo CAMBIAR SCRIPT
