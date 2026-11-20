FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        nmap \
        hping3 \
        dnsutils \
        arping \
        tcpdump \
        openssh-client \
        netcat-openbsd \
        iproute2 \
        iputils-ping \
        net-tools \
        python3 \
        ca-certificates \
        curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /audit
CMD ["tail", "-f", "/dev/null"]
