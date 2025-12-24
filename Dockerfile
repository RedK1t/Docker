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

# ---------------------------------------------------------------------------
# UPDATED LAYER: Install Tools, Themes, Fonts, and Configuration
# ---------------------------------------------------------------------------

# 1. Install System Tools & Dependencies
RUN apt-get update && apt-get install -y \
    terminator \
    xarchiver \
    zip unzip \
    p7zip-full \
    rar unrar \
    tar gzip bzip2 xz-utils \
    mousepad \
    git \
    sassc \
    libglib2.0-dev-bin \
    imagemagick \
    wget \
    fontconfig \
    sudo

# 3. Install Qogir Theme & Icons
RUN git clone https://github.com/vinceliuice/Qogir-theme.git /tmp/Qogir-theme && \
    /tmp/Qogir-theme/install.sh -d /usr/share/themes --tweaks square && \
    git clone https://github.com/vinceliuice/Qogir-icon-theme.git /tmp/Qogir-icon-theme && \
    /tmp/Qogir-icon-theme/install.sh -d /usr/share/icons && \
    rm -rf /tmp/Qogir-theme /tmp/Qogir-icon-theme

# 4. Configure XFCE Defaults (Themes, Fonts, Terminator)
# Create necessary config directories
RUN mkdir -p /home/redkit/.config/xfce4/xfconf/xfce-perchannel-xml/ && \
    mkdir -p /home/redkit/.config/xfce4/terminal/

# B. Set Terminator as Default
RUN update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator /usr/bin/terminator 50 && \
    update-alternatives --set x-terminal-emulator /usr/bin/terminator 
RUN echo 'TerminalEmulator=terminator' > /home/redkit/.config/xfce4/helpers.rc

# 5. Wallpapers
COPY default.jpg /usr/share/backgrounds/xfce
COPY xfce4-desktop.xml /home/redkit/.config/xfce4/xfconf/xfce-perchannel-xml/

RUN mkdir -p /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml

# 6. Sudo Privileges
RUN usermod -aG sudo redkit && echo 'root:root' | chpasswd && \
    chown redkit:redkit /home/redkit/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml && \
    chown -R redkit:redkit /home/redkit/.config && \
    mkdir -p /home/redkit/.config/autostart/ &&\
    echo "[Desktop Entry]\nType=Application\nName=XFCE Config Starter\nExec=xfconf-query -c xsettings -p /Net/ThemeName -s Qogir-Dark; xfconf-query -c xsettings -p /Net/IconThemeName -s Qogir-dark" > /home/redkit/.config/autostart/xfce-config-starter.desktop && \
    chown redkit:redkit /home/redkit/.config/autostart/xfce-config-starter.desktop

# -----------------------------------------------------------------------------
# STEP 1: Add Sublime Text Repository
# -----------------------------------------------------------------------------
RUN mkdir -p /etc/apt/keyrings && \
    wget -qO /etc/apt/keyrings/sublimehq-pub.gpg https://download.sublimetext.com/sublimehq-pub.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/sublimehq-pub.gpg] https://download.sublimetext.com/ apt/stable/" | tee /etc/apt/sources.list.d/sublime-text.list > /dev/null

# -----------------------------------------------------------------------------
# STEP 2: Install Sublime Text and Configure Defaults (REPLACED)
# -----------------------------------------------------------------------------
RUN apt-get update && \
    apt-get install -y sublime-text mime-support && \
    # Set system-wide default text editor
    update-alternatives --install /usr/bin/editor editor /usr/bin/subl 100 && \
    update-alternatives --set editor /usr/bin/subl && \
    # Set XFCE helper defaults for redkit
    echo 'text/plain=subl' >> /home/redkit/.config/xfce4/helpers.rc && \
    echo 'TerminalEditor=subl' >> /home/redkit/.config/xfce4/helpers.rc && \
    # Ensure ownership is set
    chown redkit:redkit /home/redkit/.config/xfce4/helpers.rc
    # NOTE: We removed the failing 'sed' command for defaults.list
	
RUN apt-get update && apt-get install -y \
    fonts-ibm-plex \
    && rm -rf /var/lib/apt/lists/*

COPY fonts/60-ibm-plex.conf /etc/fonts/conf.d/
COPY xsettings.xml /home/redkit/.config/xfce4/xfconf/xfce-perchannel-xml/

COPY gtk/settings.ini /home/redkit/.config/gtk-3.0/settings.ini
COPY xfce/terminalrc /home/redkit/.config/xfce4/terminal/terminalrc

RUN chown -R redkit:redkit /home/redkit/.config



# Optional: allow sudo without password
# RUN echo "redkit ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-redkit && \
#     chmod 440 /etc/sudoers.d/90-redkit

# 9. Start as Root
# We must start as root to launch sshd, but we switch to redkit for VNC inside the script
USER root
CMD ["/entrypoint.sh"]