# --- Stage 1: The Builder ---
FROM kalilinux/kali-rolling:latest AS python-builder
ENV DEBIAN_FRONTEND=noninteractive
ENV PYENV_ROOT="/opt/pyenv"

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev \
    libsqlite3-dev curl git libncursesw5-dev tk-dev libffi-dev liblzma-dev ca-certificates \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/pyenv/pyenv.git $PYENV_ROOT && \
    $PYENV_ROOT/bin/pyenv install 3.10.11 && \
    $PYENV_ROOT/bin/pyenv global 3.10.11 && \
    find $PYENV_ROOT -type d -name "test" -prune -exec rm -rf {} +

# --- Stage 2: Final Image ---
FROM kalilinux/kali-rolling:latest

ENV DEBIAN_FRONTEND=noninteractive
ENV PYENV_ROOT="/opt/pyenv"
ENV PATH="$PYENV_ROOT/shims:$PYENV_ROOT/bin:$PATH"

# 1. إضافة المستودعات وتثبيت كل شيء في Layer واحدة عملاقة (أفضل للمساحة)
# 1. تثبيت wget و gnupg وتهيئة مستودع Sublime
RUN apt-get update && \
    apt-get install -y --no-install-recommends wget gnupg ca-certificates && \
    mkdir -p /etc/apt/keyrings && \
    wget -qO /etc/apt/keyrings/sublimehq-pub.gpg https://download.sublimetext.com/sublimehq-pub.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/sublimehq-pub.gpg] https://download.sublimetext.com/ apt/stable/" > /etc/apt/sources.list.d/sublime-text.list

# 2. التثبيت العملاق (مع إضافة تريكة الـ Fix-Missing)
RUN apt-get update || apt-get update --fix-missing && \
    apt-get install -y --no-install-recommends \
    # GUI & VNC
    xfce4 xfce4-terminal tigervnc-standalone-server tigervnc-tools \
    novnc websockify dbus-x11 net-tools \
    # Browsers & Editors
    chromium supervisor libnss3-tools sublime-text \
    # Tools & Utilities
    openssh-server vim terminator xarchiver mousepad git sudo \
    zip unzip p7zip-full rar unrar imagemagick \
    # Fonts & Themes
    fonts-ibm-plex papirus-icon-theme fonts-noto-core \
    xfce4-whiskermenu-plugin xfce4-systemload-plugin xfce4-cpugraph-plugin \
    # Build Essentials
    build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev \
    libsqlite3-dev tk-dev libffi-dev liblzma-dev sassc libglib2.0-bin \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 2. نقل بايثون الجاهز
COPY --from=python-builder /opt/pyenv /opt/pyenv

# 3. تثبيت الـ Themes وتنظيف الـ Cache بتاعها فوراً
# 3. تثبيت الـ Themes (بنعمل update و install ونمسحهم في نفس السطر عشان الحجم)
RUN git clone --depth 1 https://github.com/vinceliuice/Qogir-theme.git /tmp/Qogir-theme && \
    /tmp/Qogir-theme/install.sh -d /usr/share/themes --tweaks square && \
    git clone --depth 1 https://github.com/RedK1t/Proxy.git /usr/share/Redkit-Proxy && \
    git clone --depth 1 https://github.com/vinceliuice/Qogir-icon-theme.git /tmp/Qogir-icon-theme && \
    /tmp/Qogir-icon-theme/install.sh -d /usr/share/icons && \
    wget -qO- https://git.io/papirus-folders-install | sh && \
    papirus-folders -C blue --theme Papirus-Dark && \
    # التنظيف النهائي عشان نخسس الـ Layer
    apt-get purge -y sassc libglib2.0-bin && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /tmp/Qogir* /var/lib/apt/lists/*

RUN pip install -r /usr/share/Redkit-Proxy/requirements.txt && \
    timeout 5s mitmdump || true && \
    # 2. Setup NSS DB and Trust Certificate
    mkdir -p /home/redkit/.pki/nssdb && \
    certutil -d sql:/home/redkit/.pki/nssdb -N --empty-password && \
    certutil -d sql:/home/redkit/.pki/nssdb -A -t "C,," -n "mitmproxy" -i /root/.mitmproxy/mitmproxy-ca-cert.pem && \
    # 4. FORCE Proxy Settings via Policy
    mkdir -p /etc/chromium/policies/managed && \
    echo '{"ProxyMode":"fixed_servers","ProxyServer":"http://127.0.0.1:8080"}' > /etc/chromium/policies/managed/proxy.json && \
    # 5. Fix Permissions
    mkdir -p /home/redkit/.mitmproxy && \
    cp /root/.mitmproxy/* /home/redkit/.mitmproxy/
# 4. إعداد المستخدم
RUN useradd -m -s /bin/bash redkit && usermod -aG sudo redkit && \
    echo 'redkit:redkit' | chpasswd && echo 'root:root' | chpasswd && \
    mkdir -p /var/run/sshd /home/redkit/.config/xfce4/terminal /home/redkit/.vnc

# 5. الـ COPY الذكي (آخر حاجة عشان الكاش)
COPY assets/ /

# 6. اللمسات الأخيرة
RUN update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator /usr/bin/terminator 50 && \
    update-alternatives --set x-terminal-emulator /usr/bin/terminator && \
    update-alternatives --install /usr/bin/editor editor /usr/bin/subl 100 && \
    update-alternatives --set editor /usr/bin/subl && \
    # Fix 'No such file' error by creating the config directory first
    mkdir -p /root/.config /home/redkit/.config && \
    touch /root/.config/mimeapps.list && \
    xdg-settings set default-web-browser chromium.desktop && \
    # Force Chromium to use the local proxy (8080) via system policy
    mkdir -p /etc/chromium/policies/managed && \
    echo '{"ProxyMode":"fixed_servers","ProxyServer":"http://127.0.0.1:8080"}' > /etc/chromium/policies/managed/proxy.json && \
    # Ensure permissions are correct across all sensitive directories
    chown -R redkit:redkit /home/redkit /opt/pyenv/shims /home/redkit/.pki /home/redkit/.mitmproxy && \
    chmod +x /entrypoint.sh && \
    chmod +x /home/redkit/.config/tigervnc/xstartup && \
    fc-cache -f -v


# Layer 4: FoxyProxy extension and Chromium sandbox fix
RUN mkdir -p /etc/chromium/policies/managed /usr/share/chromium/extensions && \
    # Policy: Only force-install FoxyProxy, disable sandbox warnings, no forced proxy
    echo '{\
  "ExtensionInstallForcelist": ["gcknhkkoolaabfmlnjonogaaifnjlfnp;https://clients2.google.com/service/update2/crx"],\
  "ChromeAppsEnabled": false,\
  "SuppressUnsupportedOSWarning": true\
}' > /etc/chromium/policies/managed/foxyproxy-only.json && \
    # Pre-configure FoxyProxy with localhost:8080 as default (user can still disable/enable via extension)
    mkdir -p /home/redkit/.config/chromium/Default/Extensions/gcknhkkoolaabfmlnjonogaaifnjlfnp/7.5.1.0 && \
    # Move original binary and create wrapper that ALWAYS uses --no-sandbox
    mv /usr/bin/chromium /usr/bin/chromium-original && \
    echo '#!/bin/bash\n/usr/bin/chromium-original --no-sandbox --disable-setuid-sandbox --disable-dev-shm-usage "$@"' > /usr/bin/chromium && \
    chmod +x /usr/bin/chromium && \
    # Also wrap chromium-browser if it exists
    if [ -f /usr/bin/chromium-browser ]; then \
        mv /usr/bin/chromium-browser /usr/bin/chromium-browser-original && \
        echo '#!/bin/bash\n/usr/bin/chromium-browser-original --no-sandbox --disable-setuid-sandbox --disable-dev-shm-usage "$@"' > /usr/bin/chromium-browser && \
        chmod +x /usr/bin/chromium-browser; \
    fi && \
    # Update alternatives to point to our wrapper
    update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/bin/chromium 100 && \
    update-alternatives --set x-www-browser /usr/bin/chromium && \
    update-alternatives --install /usr/bin/gnome-www-browser gnome-www-browser /usr/bin/chromium 100 && \
    update-alternatives --set gnome-www-browser /usr/bin/chromium && \
    chown -R redkit:redkit /home/redkit/.config/chromium

EXPOSE 6080
USER root
CMD ["/entrypoint.sh"]