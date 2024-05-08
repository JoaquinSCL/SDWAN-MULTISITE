FROM ubuntu:22.04

RUN apt-get clean
RUN apt-get update \
    && apt-get install -y \
    apt-utils \
    systemctl \
    iptables \
    openvpn \
    net-tools \
    traceroute \
    build-essential \
    inetutils-ping \
    bridge-utils \
    tcpdump \
    openvswitch-switch \
    openvswitch-common \
    iperf \
    iproute2 \
    curl \
    nano \
    psmisc \
    wireguard \
    netplan.io


COPY claves /claves
COPY vnx_config_nat vnx_config_nat

RUN chmod +x vnx_config_nat
