#!/bin/bash
cd ~/shared/sdedge-ns/bin
./rdsv-start-tun S labtun5.dit.upm.es
ping -c 3 10.11.13.1
osm ns-delete --force sdedge1
osm ns-delete --force sdedge2
cd ~/shared
