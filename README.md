
Repository for SD-WAN lab with k8s.
 
The lab manual, in Spanish, is [here](doc/rdsv-p4.md)

In this branch the tunnel between central offices has been replaced by a tunnel
between KNF-cpe-1 and bcg0.

It can be tested by executing the following commands:

```bash
bin/prepare-k8slab
source ~/.bashrc

sudo vnx -f vnx/sdedge_nfv.xml -t

./sdedge1.sh

./sdwan1.sh

./sdedge2.sh

./sdwan2.sh
```

Then, enter r1 and r2 consoles and ping r0

```bash
# from r1
ping 10.20.0.100
```
