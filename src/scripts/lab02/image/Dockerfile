FROM ubuntu:20.04
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    net-tools \
    iproute2 \
    iputils-ping \
    traceroute \
    tcpdump \
    netcat \
    curl \
    nano \
    python3 \
    python3-pip \
    iptables \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install scapy

WORKDIR /
CMD ["/bin/bash"]

