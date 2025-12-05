#!/bin/bash
echo "Starting VNC Server (as redkit)..."
su - redkit -c 'vncserver :1 -SecurityTypes none -geometry 1280x800 -depth 24'

echo "Waiting for VNC server to start..."
sleep 3

echo "Checking VNC server status..."
su - redkit -c 'vncserver -list'

echo "Starting NoVNC (as redkit)..."
su - redkit -c 'websockify --web=/usr/share/novnc 6080 localhost:5901' &

# Keep the container running in the foreground
tail -f /dev/null