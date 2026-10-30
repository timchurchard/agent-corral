#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get install -y xfce4 xfce4-goodies tigervnc-standalone-server tigervnc-common \
  dbus-x11

install -d -o vagrant -g vagrant -m 700 /home/vagrant/.vnc

cat > /home/vagrant/.vnc/xstartup <<'EOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec startxfce4
EOF
chown vagrant:vagrant /home/vagrant/.vnc/xstartup
chmod 700 /home/vagrant/.vnc/xstartup

cat > /etc/systemd/system/vncserver@.service <<'EOF'
[Unit]
Description=Remote desktop service (VNC) on display %i
After=syslog.target network.target

[Service]
Type=forking
User=vagrant
Group=vagrant
WorkingDirectory=/home/vagrant

PIDFile=/home/vagrant/.vnc/%H%i.pid
ExecStartPre=-/usr/bin/vncserver -kill %i > /dev/null 2>&1
ExecStart=/usr/bin/vncserver -localhost no -depth 24 -geometry 1920x1080 %i
ExecStop=/usr/bin/vncserver -kill %i

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

# Not started/enabled here: vncserver refuses to run until a password is set
# via `vncpasswd`, which is an interactive, per-machine, secret step -- see
# README.md's post-`vagrant up` instructions.
