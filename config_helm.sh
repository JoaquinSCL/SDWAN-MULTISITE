#!/bin/bash

export OSMNS=rdsv

cd img

curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3

chmod 700 get_helm.sh

./get_helm.sh

mkdir $HOME/helm-files

# crear en helm-files los paquetes correspondientes a los helm charts

cd ~/helm-files

helm package ~/shared/sdedge-ns/helm/accesschart

helm package ~/shared/sdedge-ns/helm/cpechart

helm package ~/shared/sdedge-ns/helm/wanchart

helm repo index --url http://10.11.13.74/ .

#correr docker con helm

docker run --restart always --name helm-repo -p 80:80 -v ~/helm-files:/usr/share/nginx/html:ro -d nginx

cd ~/shared
