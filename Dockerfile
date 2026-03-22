FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:1
ENV RESOLUTION=1280x800

RUN apt-get update && apt-get install -y \
    xfce4 \
    xfce4-terminal \
    tigervnc-standalone-server \
    tigervnc-common \
    novnc \
    websockify \
    dbus-x11 \
    dbus \
    gnupg \
    curl \
    wget \
    git \
    nano \
    sudo \
    fonts-liberation \
    xfonts-base \
    --no-install-recommends

RUN curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x738BEB9321D1AAEC13EA9391AEBDF4819BE21867" \
    | gpg --dearmor -o /etc/apt/trusted.gpg.d/mozillateam-ppa.gpg && \
    echo "deb https://ppa.launchpadcontent.net/mozillateam/ppa/ubuntu jammy main" \
    > /etc/apt/sources.list.d/mozillateam.list && \
    printf 'Package: *\nPin: release o=LP-PPA-mozillateam\nPin-Priority: 1001\n' \
    > /etc/apt/preferences.d/mozilla-firefox && \
    apt-get update && \
    apt-get install -y --allow-downgrades firefox && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Shared memory fix for Firefox baked into profile
RUN mkdir -p /root/.mozilla/firefox && \
    printf '[Profile0]\nName=default\nIsRelative=1\nPath=default\nDefault=1\n\n[General]\nStartWithLastProfile=1\nVersion=2\n' \
    > /root/.mozilla/firefox/profiles.ini && \
    mkdir -p /root/.mozilla/firefox/default && \
    printf 'user_pref("media.peerconnection.enabled", false);\nuser_pref("browser.tabs.remote.autostart", false);\nuser_pref("dom.ipc.processCount", 1);\n' \
    > /root/.mozilla/firefox/default/user.js

# TigerVNC setup
RUN mkdir -p /root/.vnc && \
    echo "1234" | vncpasswd -f > /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

RUN printf '#!/bin/bash\n\
unset SESSION_MANAGER\n\
unset DBUS_SESSION_BUS_ADDRESS\n\
exec startxfce4\n' > /root/.vnc/xstartup && \
    chmod +x /root/.vnc/xstartup

# noVNC full height
RUN printf '<!DOCTYPE html>\n\
<html>\n\
<head><title>Desktop</title><meta charset="utf-8"/>\n\
<style>*{margin:0;padding:0}html,body{width:100%%;height:100%%;background:#000}iframe{width:100%%;height:100vh;border:none}</style>\n\
</head>\n\
<body><iframe src="/vnc.html?autoconnect=true&reconnect=true&password=1234&resize=scale"></iframe></body>\n\
</html>\n' > /usr/share/novnc/index.html

RUN printf '#!/bin/bash\n\
mkdir -p /run/dbus\n\
mkdir -p /dev/shm\n\
mount -t tmpfs -o size=512m tmpfs /dev/shm 2>/dev/null || true\n\
dbus-daemon --system --fork 2>/dev/null || true\n\
eval $(dbus-launch --sh-syntax)\n\
export DBUS_SESSION_BUS_ADDRESS\n\
vncserver :1 -geometry ${RESOLUTION} -depth 24 -localhost no\n\
websockify --web=/usr/share/novnc 6080 localhost:5901 &\n\
tail -f /root/.vnc/*.log\n' > /start.sh && chmod +x /start.sh

EXPOSE 5901 6080

CMD ["/start.sh"]
