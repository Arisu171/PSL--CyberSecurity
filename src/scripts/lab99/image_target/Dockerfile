FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        openssh-server \
        sudo \
        ufw \
        fail2ban \
        auditd \
        audispd-plugins \
        apparmor \
        apparmor-utils \
        unattended-upgrades \
        apt-listchanges \
        libpam-pwquality \
        lynis \
        net-tools \
        iproute2 \
        procps \
        ca-certificates \
        curl \
        sqlite3 \
        python3 \
        python3-yaml \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash labuser \
    && echo 'labuser:Lab99Pass!' | chpasswd \
    && usermod -aG sudo labuser \
    && echo 'labuser ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/labuser \
    && chmod 0440 /etc/sudoers.d/labuser \
    && mkdir -p /var/run/sshd /volumes /hardening /audit \
    && ssh-keygen -A

# Trang thai "truoc hardening": password auth bat, root login permit (de so sanh).
RUN sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config \
    && echo 'root:RootLab99!' | chpasswd

COPY lab99_app.py /usr/local/bin/lab99_app.py
RUN chmod +x /usr/local/bin/lab99_app.py

COPY start.sh /usr/local/bin/start-lab99-target.sh
RUN chmod +x /usr/local/bin/start-lab99-target.sh

EXPOSE 22 8080
CMD ["/usr/local/bin/start-lab99-target.sh"]
