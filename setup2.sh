#!/bin/bash

cd ~/shared/sdedge-ns/bin

osm ns-delete --force sdedge1

osm ns-delete --force sdedge2

sleep 20

./rdsv-config-osmlab S

cd ~/shared