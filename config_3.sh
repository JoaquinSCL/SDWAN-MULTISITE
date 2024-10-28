#!/bin/bash

echo Parte 1

echo "-- OSM_USER=$OSM_USER"
echo "-- OSM_PASSWORD=$OSM_PASSWORD"
echo "-- OSM_PROJECT=$OSM_PROJECT"
echo "-- OSM_HOSTNAME=$OSM_HOSTNAME"
echo "-- OSMNS=$OSMNS"

firefox 10.11.13.1 &

echo Parte 2

cd img

curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3

chmod 700 get_helm.sh

./get_helm.sh

mkdir $HOME/helm-files

# crear en helm-files los paquetes correspondientes a los helm charts

cd ~/helm-files

helm package ~/shared/rdsv-final/helm/accesschart

helm package ~/shared/rdsv-final/helm/cpechart

helm package ~/shared/rdsv-final/helm/wanchart

helm package ~/shared/rdsv-final/helm/cpe-public-keys

helm repo index --url http://10.11.13.74/ .

#correr docker con helm

docker run --restart always --name helm-repo -p 80:80 -v ~/helm-files:/usr/share/nginx/html:ro -d nginx

cd ~/shared/sdedge-ns

export NSID1=$(osm ns-create --ns_name sdedge1 --nsd_name sdedge --vim_account dummy_vim)

echo "NSID=$NSID1"

export NSID2=$(osm ns-create --ns_name sdedge2 --nsd_name sdedge --vim_account dummy_vim)

echo "NSID=$NSID2"

watch osm ns-list

cd ~/shared
