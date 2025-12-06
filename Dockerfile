# 1. Base Image
FROM kalilinux/kali-rolling:latest

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

RUN rm -f /etc/apt/sources.list && \
    rm -f /etc/apt/sources.list.d/*.list && \
    echo "deb http://kali.download/kali kali-rolling main non-free-firmware non-free contrib" \
    > /etc/apt/sources.list && \
    echo "Acquire::http::No-Cache true;"  >  /etc/apt/apt.conf.d/99no-mirror-cache && \
    echo "Acquire::https::No-Cache true;" >> /etc/apt/apt.conf.d/99no-mirror-cache

# 2. Install GUI, VNC, Browser AND SSH
# We use --no-install-recommends to keep the image lighter
RUN apt-get update && apt-get install -y --no-install-recommends \
    apt-utils \
    xfce4 \
    xfce4-terminal \
    tigervnc-standalone-server \
    tigervnc-tools \
    novnc \
    websockify \
    dbus-x11 \
    net-tools \
    firefox-esr \
    openssh-server \
    vim \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 3. Setup the 'redkit' user (Standard User, NO Root Privileges)
# We create the user but do NOT add them to the sudoers group.
RUN useradd -m -s /bin/bash redkit

# 4. Configure SSH
# Create the privilege separation directory
RUN mkdir -p /var/run/sshd
# Set a Linux password for the 'redkit' user so they can SSH in
# Change 'redkitsshpassword' to whatever default you want
RUN echo 'redkit:redkit' | chpasswd
# explicitely allow password authentication
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# 5. Lock the Root Account
# This prevents anyone from doing 'su root' even if they guess a password
# RUN passwd -l root

# 6. Setup VNC (As redkit user)
WORKDIR /home/redkit
RUN mkdir -p /home/redkit/.config/tigervnc

# Set VNC password - disabled for no authentication
RUN mkdir -p /home/redkit/.config/tigervnc && \
    chown -R redkit:redkit /home/redkit/.config

# Configure XFCE startup and disable VNC password
RUN mkdir -p /home/redkit/.config/tigervnc && \
    mkdir -p /home/redkit/.vnc && \
    echo "#!/bin/sh" > /home/redkit/.config/tigervnc/xstartup && \
    echo "unset SESSION_MANAGER" >> /home/redkit/.config/tigervnc/xstartup && \
    echo "unset DBUS_SESSION_BUS_ADDRESS" >> /home/redkit/.config/tigervnc/xstartup && \
    echo "exec dbus-launch --exit-with-session startxfce4" >> /home/redkit/.config/tigervnc/xstartup && \
    chmod +x /home/redkit/.config/tigervnc/xstartup && \
    echo "session=xfce" > /home/redkit/.vnc/config && \
    echo "securityTypes=none" >> /home/redkit/.vnc/config && \
    echo "geometry=0x0" >> /home/redkit/.vnc/config && \
    echo "depth=32" >> /home/redkit/.vnc/config && \
    echo "RemoteResize=1" >> /home/redkit/.vnc/config

# Fix ownership so redkit can run the process
RUN chown -R redkit:redkit /home/redkit/.config

# 7. Create the Entrypoint Script
# We need to start VNC and NoVNC
RUN echo "#!/bin/bash" > /entrypoint.sh && \
    echo "echo 'Starting VNC Server (as redkit)...'" >> /entrypoint.sh && \
    echo "su - redkit -c 'vncserver :1 -SecurityTypes none -geometry 0x0 -depth 32'" >> /entrypoint.sh && \
    echo "echo 'Waiting for VNC server to start...'" >> /entrypoint.sh && \
    echo "sleep 3" >> /entrypoint.sh && \
    echo "echo 'Checking VNC server status...'" >> /entrypoint.sh && \
    echo "su - redkit -c 'vncserver -list'" >> /entrypoint.sh && \
    echo "echo 'Starting NoVNC (as redkit)...'" >> /entrypoint.sh && \
    echo "su - redkit -c 'websockify --web=/usr/share/novnc 6080 localhost:5901' &" >> /entrypoint.sh && \
    echo "tail -f /dev/null" >> /entrypoint.sh && \
    chmod +x /entrypoint.sh

# 8. Expose Ports
# 6080 = Web Interface (NoVNC)
EXPOSE 6080

# Install Tilix and Mousepad, set Tilix as default terminal emulator
RUN apt-get update && apt-get install -y \
    terminator \
    xarchiver \
    zip unzip \
    p7zip-full \
    rar unrar \
    tar gzip bzip2 xz-utils \
    mousepad

COPY xfce4-desktop.xml /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/
COPY wall-redkit-1.jpg wall-redkit-2.jpg /usr/share/backgrounds/xfce/

# Install sudo
RUN apt-get install -y sudo

# Give redkit sudo privileges
RUN usermod -aG sudo redkit && echo 'root:root' | chpasswd

# Optional: allow sudo without password
# RUN echo "redkit ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-redkit && \
#     chmod 440 /etc/sudoers.d/90-redkit

# 9. Start as Root
# We must start as root to launch sshd, but we switch to redkit for VNC inside the script
USER root
CMD ["/entrypoint.sh"]