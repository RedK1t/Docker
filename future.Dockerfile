FROM baseImage

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    wireshark \
    tshark \
    tcpdump \
    traceroute \
    iputils-ping \
    dnsutils \
    whois \
    iproute2 \
    netcat-traditional \
    ftp \
    grep \
    ngrep \
    sed \
    bind9-host \
    net-tools && \
    echo "wireshark-common wireshark-common/install-setuid boolean true" | debconf-set-selections && \
    DEBIAN_FRONTEND=noninteractive dpkg-reconfigure wireshark-common && \
    useradd -m redkit || true && \
    usermod -aG wireshark redkit && \
    setcap cap_net_raw,cap_net_admin=eip /usr/bin/dumpcap && \
    setcap cap_net_raw,cap_net_admin=eip /usr/sbin/tcpdump

USER redkit