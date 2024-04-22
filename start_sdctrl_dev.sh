#!/bin/bash

# Requires the following variables
# KUBECTL: kubectl command
# OSMNS: OSM namespace in the cluster vim
# NETNUM: used to select external networks
# VCPE: "pod_id" or "deploy/deployment_id" of the cpd vnf
# VWAN: "pod_id" or "deploy/deployment_id" of the wan vnf
# REMOTESITE: the "public" IP of the remote site

set -u # to verify variables are defined
: $KUBECTL
: $OSMNS
: $VCTRL

if [[ ! $VCTRL =~ "sdedge-ns-repo-wanchart"  ]]; then
    echo ""       
    echo "ERROR: incorrect <wan_deployment_id>: $VCTRL"
    exit 1
fi

CTRL_EXEC="$KUBECTL exec -n $OSMNS $VCTRL --"

## 1. En VNF:ctrl arrancar controlador SDN"
echo "## 1. En VNF:ctrl arrancar controlador SDN"
#$CTRL_EXEC /usr/local/bin/ryu-manager --verbose flowmanager/flowmanager.py ryu.app.ofctl_rest 2>&1 | tee ryu.log &
#$CTRL_EXEC /usr/local/bin/ryu-manager ryu.app.simple_switch_13 ryu.app.ofctl_rest 2>&1 | tee ryu.log &
#$CTRL_EXEC /usr/local/bin/ryu-manager flowmanager/flowmanager.py ryu.app.ofctl_rest 2>&1 | tee ryu.log &
$CTRL_EXEC chmod +x ./qos_simple_switch_13.py
$CTRL_EXEC /usr/local/bin/ryu-manager ryu.app.rest_qos ryu.app.rest_conf_switch ./qos_simple_switch_13.py ryu.app.ofctl_rest flowmanager/flowmanager.py 2>&1 | tee ryu.log &


