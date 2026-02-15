#!/bin/bash
echo "$(date) - Starting VNC Server (as redkit)..."
su - redkit -c 'vncserver :1 -localhost no -SecurityTypes none -depth 32 --I-KNOW-THIS-IS-INSECURE'
echo "$(date) - Waiting for VNC server to start..."
sleep 5
echo "$(date) - Checking VNC server status..."
su - redkit -c 'vncserver -list'
echo "$(date) - Starting NoVNC (as redkit)..."
su - redkit -c 'websockify --web=/usr/share/novnc 0.0.0.0:6080 localhost:5901' &
echo "$(date) - Startup complete. Tail logs..."
echo "$(date) - Starting Proxy"
su - root -c '/usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf' &
echo "$(date) - Startup complete. Tail logs..."
tail -f /dev/null
