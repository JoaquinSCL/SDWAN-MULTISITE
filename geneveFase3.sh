helm uninstall server1
helm uninstall server2
helm uninstall client
helm uninstall test1
helm uninstall test2
helm uninstall internet

sudo tc qdisc del dev geneve1 root
sudo tc qdisc del dev geneve1 ingress

kubectl get all

exit
clear
kubectl exec -it  -- /bin/bash

helm install client cpechart/ --values cpechart/values.yaml --set deployment.network="extnet1"
helm install server1 cpechart/ --values cpechart/values.yaml --set deployment.network="extnet1\,extnet2\,extnet3"
helm install server2 cpechart/ --values cpechart/values.yaml --set deployment.network="extnet2\,extnet3"
helm install test1 cpechart/ --values cpechart/values.yaml --set deployment.network="extnet3"
helm install test2 cpechart/ --values cpechart/values.yaml --set deployment.network="extnet3"
helm install internet cpechart/ --values cpechart/values.yaml --set deployment.network="extnet2"

#Client-------------------------------------------------------------
ifconfig net1 10.100.1.2/24
ip link add name geneve0 type geneve external dstport 6081
ip link set geneve0 up
sudo tc qdisc add dev geneve0 root handle 1: prio
sudo tc filter add dev geneve0 parent 1: \
    protocol ip \
    flower dst_ip 10.100.3.3 \
    action tunnel_key set \
    src_ip 10.100.1.2 \
    dst_ip 10.100.1.1 \
    dst_port 6081 \
    id 1000 \
    geneve_opts 0FF01:80:11111111 \
    pass
sudo tc filter add dev geneve0 parent 1: \
    protocol ip \
    flower dst_ip 10.100.3.4 \
    action tunnel_key set \
    src_ip 10.100.1.2 \
    dst_ip 10.100.1.1 \
    dst_port 6081 \
    id 1000 \
    geneve_opts 0FF01:80:22222222 \
    pass
sudo tc filter add dev geneve0 parent 1: \
    protocol ip \
    flower dst_ip 10.200.1.3 \
    action tunnel_key set \
    src_ip 10.100.1.2 \
    dst_ip 10.100.1.1 \
    dst_port 6081 \
    id 1000 \
    geneve_opts 0FF01:80:44444444 \
    pass
sudo tc filter add dev geneve0 parent 1: \
    protocol arp \
    matchall \
    action tunnel_key set \
    src_ip 10.100.1.2 \
    dst_ip 10.100.1.1 \
    dst_port 6081 \
    id 1000 \
    action pass
sudo ip addr add 10.100.3.8/24 dev geneve0
ip neigh flush dev geneve0
sudo ip route add 10.100.3.3 dev geneve0
sudo ip route add 10.100.3.4 dev geneve0
sudo ip route add 10.200.1.3 dev geneve0
sudo tc qdisc add dev geneve0 ingress
sudo tc filter add dev geneve0 parent ffff: prio 10 \
    flower geneve_opts 0FF01:80:11111111 \
    action tunnel_key unset \
    action pass
sudo tc filter add dev geneve0 parent ffff: prio 10 \
    flower geneve_opts 0FF01:80:22222222 \
    action tunnel_key unset \
    action pass
sudo tc filter add dev geneve0 parent ffff: prio 10 \
    flower geneve_opts 0FF01:80:44444444 \
    action tunnel_key unset \
    action pass
sudo tc filter add dev geneve0 parent ffff: prio 11 \
    protocol arp \
    matchall \
    action tunnel_key unset \
    action pass

#Server-------------------------------------------------------------
ifconfig net1 10.100.1.1/24
ifconfig net2 10.200.1.1/24
ip link add name geneve0 type geneve external dstport 6081
ip link set geneve0 up
ip link add name geneve1 type geneve external dstport 6084
ip link set geneve1 up

sudo tc qdisc add dev geneve0 ingress
sudo tc filter add dev geneve0 parent ffff: prio 10 \
    flower geneve_opts 0FF01:80:11111111 \
    action tunnel_key unset \
    action mirred egress redirect dev net3
sudo tc filter add dev geneve0 parent ffff: prio 10 \
    flower geneve_opts 0FF01:80:22222222 \
    action mirred egress redirect dev geneve1
sudo tc filter add dev geneve0 parent ffff: prio 10 \
    flower geneve_opts 0FF01:80:44444444 \
    action tunnel_key unset \
    action mirred egress redirect dev net2
sudo tc filter add dev geneve0 parent ffff: prio 11 \
    protocol arp \
    flower arp_tip 10.100.3.3 \
    action tunnel_key unset \
    action mirred egress redirect dev net3
sudo tc filter add dev geneve0 parent ffff: prio 11 \
    protocol arp \
    flower arp_tip 10.100.3.4 \
    action mirred egress redirect dev geneve1
sudo tc filter add dev geneve0 parent ffff: prio 11 \
    protocol arp \
    flower arp_tip 10.200.1.3 \
    action tunnel_key unset \
    action mirred egress redirect dev net2
    
sudo tc qdisc add dev geneve1 ingress
sudo tc filter add dev geneve1 parent ffff: prio 10 \
    flower geneve_opts 0FF01:80:33333333 \
    action mirred egress redirect dev geneve0         
sudo tc filter add dev geneve1 parent ffff: prio 11 \
    protocol arp \
    matchall \
    action mirred egress redirect dev geneve0


ip addr add 10.100.3.1/24 dev geneve0
ip addr add 10.100.3.2/24 dev geneve1

sudo tc qdisc add dev geneve0 root handle 1: prio
sudo tc filter add dev geneve0 parent 1: \
    protocol ip \
    flower src_ip 10.100.3.3  \
    action tunnel_key set \
    src_ip 10.100.1.1 \
    dst_ip 10.100.1.2 \
    dst_port 6081 \
    id 1000 \
    geneve_opts 0FF01:80:11111111 \
    pass
sudo tc filter add dev geneve0 parent 1: \
    protocol ip \
    flower src_ip 10.100.3.4 \
    action tunnel_key set \
    src_ip 10.100.1.1 \
    dst_ip 10.100.1.2 \
    dst_port 6081 \
    id 1000 \
    geneve_opts 0FF01:80:22222222 \
    pass
sudo tc filter add dev geneve0 parent 1: \
    protocol ip \
    flower src_ip 10.200.1.3 \
    action tunnel_key set \
    src_ip 10.100.1.1 \
    dst_ip 10.100.1.2 \
    dst_port 6081 \
    id 1000 \
    geneve_opts 0FF01:80:44444444 \
    pass
sudo tc filter add dev geneve0 parent 1: \
    protocol arp \
    matchall \
    action tunnel_key set \
    src_ip 10.100.1.1 \
    dst_ip 10.100.1.2 \
    dst_port 6081 \
    id 1000 \
    action pass

sudo tc qdisc add dev geneve1 root handle 2: prio
sudo tc filter add dev geneve1 parent 2: \
    protocol ip \
    flower dst_ip 10.100.3.4 \
    action tunnel_key set \
    src_ip 10.200.1.1 \
    dst_ip 10.200.1.2 \
    dst_port 6084 \
    id 1000 \
    geneve_opts 0FF01:80:33333333 \
    pass
sudo tc filter add dev geneve1 parent 2: \
    protocol arp \
    matchall \
    action tunnel_key set \
    src_ip 10.200.1.1 \
    dst_ip 10.200.1.2 \
    dst_port 6084 \
    id 1000 \
    pass
   
tc qdisc add dev net3 ingress
tc filter add dev net3 parent ffff: \
    protocol ip \
    flower src_ip 10.100.3.3 \
    action mirred egress redirect dev geneve0
tc filter add dev net3 parent ffff: \
    protocol arp \
    matchall \
    action mirred egress redirect dev geneve0
    
tc qdisc add dev net2 ingress
tc filter add dev net2 parent ffff: \
    protocol ip \
    flower src_ip 10.200.1.3 \
    action mirred egress redirect dev geneve0
tc filter add dev net2 parent ffff: \
    protocol arp \
    flower arp_sip 10.200.1.3 \
    action mirred egress redirect dev geneve0
    
#Server2-------------------------------------------------------------     
ifconfig net1 10.200.1.2/24
ip link add name geneve1 type geneve external dstport 6084
ip link set geneve1 up
sudo tc qdisc add dev geneve1 ingress
sudo tc filter add dev geneve1 parent ffff: prio 10 \
    flower geneve_opts 0FF01:80:33333333 \
    action tunnel_key unset \
    action mirred egress redirect dev net2
sudo tc filter add dev geneve1 parent ffff: prio 11 \
    protocol arp \
    matchall \
    action tunnel_key unset \
    action mirred egress redirect dev net2


ip addr add 10.100.3.5/24 dev geneve1

sudo tc qdisc add dev geneve1 root handle 1: prio
sudo tc filter add dev geneve1 parent 1: \
    protocol ip \
    flower src_ip 10.100.3.4 \
    action tunnel_key set \
    src_ip 10.200.1.2 \
    dst_ip 10.200.1.1 \
    dst_port 6084 \
    id 1000 \
    geneve_opts 0FF01:80:33333333 \
    pass
sudo tc filter add dev geneve1 parent 1: \
    protocol arp \
    matchall \
    action tunnel_key set \
    src_ip 10.200.1.2 \
    dst_ip 10.200.1.1 \
    dst_port 6084 \
    id 1000 \
    pass
    
tc qdisc add dev net2 ingress
tc filter add dev net2 parent ffff: \
    protocol ip \
    flower src_ip 10.100.3.4 \
    action mirred egress redirect dev geneve1
tc filter add dev net2 parent ffff: \
    protocol arp \
    matchall \
    action mirred egress redirect dev geneve1

#Test1------------------------------------------------------------
ifconfig net1 10.100.3.3/24
ip neigh flush dev net1
#Test2------------------------------------------------------------
ifconfig net1 10.100.3.4/24
ip neigh flush dev net1
#Internet---------------------------------------------------------
ifconfig net1 10.200.1.3/24
sudo ip route add 10.100.3.8 dev net1
