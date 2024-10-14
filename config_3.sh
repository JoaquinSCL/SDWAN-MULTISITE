#!/bin/bash

echo Parte 1

firefox 10.11.13.1 &

cd vnx

sudo vnx --modify-rootfs /usr/share/vnx/filesystems/vnx_rootfs_lxc_ubuntu64-20.04-v025-vnxlab/

sudo vnx -f sdedge_nfv.xml -t

echo Parte 2

cd ~/shared/rdsv-final/img

curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3

chmod 700 get_helm.sh

./get_helm.sh

mkdir $HOME/helm-files

# crear en helm-files los paquetes correspondientes a los helm charts

cd ~/helm-files

helm package ~/shared/rdsv-final/helm/accesschart

helm package ~/shared/rdsv-final/helm/cpechart

helm package ~/shared/rdsv-final/helm/wanchart

helm repo index --url http://10.11.13.74/ .

#correr docker con helm

docker run --restart always --name helm-repo -p 80:80 -v ~/helm-files:/usr/share/nginx/html:ro -d nginx

cd ~/shared/rdsv-final

export NSID1=$(osm ns-create --ns_name sdedge1 --nsd_name sdedge --vim_account dummy_vim)

echo "NSID=$NSID1"

export NSID2=$(osm ns-create --ns_name sdedge2 --nsd_name sdedge --vim_account dummy_vim)

echo "NSID=$NSID2"

watch osm ns-list

cd ~/shared
