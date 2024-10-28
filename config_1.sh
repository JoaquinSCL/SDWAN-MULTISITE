#!/bin/bash

echo Parte inicial

cd bin

./rdsv-start-tun S labtun5.dit.upm.es

echo "Empieza el sleep"
sleep 5
echo "Termina el sleep"

ping -c 3 10.11.13.1

osm ns-delete --force sdedge1

osm ns-delete --force sdedge2
