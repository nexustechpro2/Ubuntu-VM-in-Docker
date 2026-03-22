FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:1
ENV RESOLUTION=1280x800
ENV MOZ_DISABLE_CONTENT_SANDBOX=1
ENV MOZ_NO_REMOTE=1
ENV MOZ_DISABLE_AUTO_SAFE_MODE=1
ENV TMPDIR=/tmp

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
    python3 \
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

# Firefox profile - disable everything that needs shm or sandbox
RUN mkdir -p /root/.mozilla/firefox/default && \
    printf '[Profile0]\nName=default\nIsRelative=1\nPath=default\nDefault=1\n\n[General]\nStartWithLastProfile=1\nVersion=2\n' \
    > /root/.mozilla/firefox/profiles.ini && \
    printf 'user_pref("browser.tabs.remote.autostart", false);\n\
user_pref("dom.ipc.processCount", 1);\n\
user_pref("media.peerconnection.enabled", false);\n\
user_pref("gfx.webrender.all", false);\n\
user_pref("gfx.webrender.enabled", false);\n\
user_pref("layers.acceleration.disabled", true);\n\
user_pref("toolkit.startup.max_resumed_crashes", -1);\n\
user_pref("browser.sessionstore.resume_from_crash", false);\n\
user_pref("browser.shell.checkDefaultBrowser", false);\n\
user_pref("datareporting.healthreport.uploadEnabled", false);\n\
user_pref("toolkit.telemetry.enabled", false);\n' \
    > /root/.mozilla/firefox/default/user.js

# Firefox wrapper that redirects shm to /tmp
RUN printf '#!/bin/bash\nexec firefox --profile /root/.mozilla/firefox/default --no-remote --new-instance "$@"\n' \
    > /usr/local/bin/firefox && chmod +x /usr/local/bin/firefox

RUN mkdir -p /root/.vnc && \
    printf '#!/bin/bash\nunset SESSION_MANAGER\nunset DBUS_SESSION_BUS_ADDRESS\nexec startxfce4\n' \
    > /root/.vnc/xstartup && \
    chmod +x /root/.vnc/xstartup

RUN printf '<!DOCTYPE html>\n\
<html>\n\
<head><title>Desktop</title><meta charset="utf-8"/>\n\
<style>*{margin:0;padding:0}html,body{width:100%%;height:100%%;background:#000}iframe{width:100%%;height:100vh;border:none}</style>\n\
</head>\n\
<body><iframe src="/vnc.html?autoconnect=true&reconnect=true&resize=scale"></iframe></body>\n\
</html>\n' > /usr/share/novnc/index.html

# Symlink /dev/shm to /tmp/shm as fallback
RUN mkdir -p /tmp/shm && \
    rm -rf /dev/shm && \
    ln -sf /tmp/shm /dev/shm

RUN printf '#!/bin/bash\n\
mkdir -p /run/dbus /root/.vnc /tmp/shm\n\
dbus-daemon --system --fork 2>/dev/null || true\n\
eval $(dbus-launch --sh-syntax)\n\
export DBUS_SESSION_BUS_ADDRESS\n\
vncserver :1 -geometry ${RESOLUTION} -depth 24 -localhost no -SecurityTypes None --I-KNOW-THIS-IS-INSECURE\n\
sleep 2\n\
websockify --web=/usr/share/novnc 6080 localhost:5901 &\n\
tail -f /dev/null\n' > /start.sh && chmod +x /start.sh

EXPOSE 5901 6080

CMD ["/start.sh"]
