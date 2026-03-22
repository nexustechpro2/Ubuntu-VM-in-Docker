FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:1
ENV RESOLUTION=1280x720x24

RUN apt-get update && apt-get install -y \
    xfce4 \
    xfce4-goodies \
    x11vnc \
    xvfb \
    novnc \
    websockify \
    wget \
    curl \
    git \
    sudo \
    nano \
    gnupg \
    dbus \
    dbus-x11 \
    at-spi2-core \
    pm-utils \
    software-properties-common \
    --no-install-recommends

RUN curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x738BEB9321D1AAEC13EA9391AEBDF4819BE21867" \
    | gpg --dearmor -o /etc/apt/trusted.gpg.d/mozillateam-ppa.gpg && \
    echo "deb https://ppa.launchpadcontent.net/mozillateam/ppa/ubuntu jammy main" \
    > /etc/apt/sources.list.d/mozillateam.list && \
    printf 'Package: *\nPin: release o=LP-PPA-mozillateam\nPin-Priority: 1001\n' \
    > /etc/apt/preferences.d/mozilla-firefox

RUN apt-get update && apt-get install -y --allow-downgrades firefox && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Disable xfwm4 compositor to fix the compositing conflict
RUN mkdir -p /root/.config/xfce4/xfconf/xfce-perchannel-xml && \
    printf '<?xml version="1.0" encoding="UTF-8"?>\n\
<channel name="xfwm4" version="1.0">\n\
  <property name="general" type="empty">\n\
    <property name="use_compositing" type="bool" value="false"/>\n\
  </property>\n\
</channel>\n' > /root/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml

RUN mkdir -p /root/.vnc && \
    x11vnc -storepasswd 1234 /root/.vnc/passwd

# noVNC full height index
RUN printf '<!DOCTYPE html>\n\
<html style="height:100%%;margin:0;padding:0;">\n\
<head>\n\
<title>Desktop</title>\n\
<meta charset="utf-8"/>\n\
<style>\n\
* { margin:0; padding:0; box-sizing:border-box; }\n\
html, body { width:100%%; height:100%%; overflow:hidden; background:#000; }\n\
iframe { width:100%%; height:100vh; border:none; display:block; }\n\
</style>\n\
</head>\n\
<body>\n\
<iframe src="/vnc.html?autoconnect=true&reconnect=true&password=1234&resize=scale"></iframe>\n\
</body>\n\
</html>\n' > /usr/share/novnc/index.html

RUN printf '#!/bin/bash\n\
# Start system dbus\n\
mkdir -p /run/dbus\n\
dbus-daemon --system --fork 2>/dev/null || true\n\
sleep 1\n\
# Start session dbus\n\
eval $(dbus-launch --sh-syntax)\n\
export DBUS_SESSION_BUS_ADDRESS\n\
# Start Xvfb\n\
Xvfb :1 -screen 0 ${RESOLUTION} &\n\
sleep 1\n\
# Start XFCE (compositor disabled via config)\n\
startxfce4 &\n\
sleep 3\n\
# Kill any stray compositors\n\
xfwm4 --replace --compositor=off 2>/dev/null || true\n\
# Start VNC\n\
x11vnc -display :1 -rfbauth /root/.vnc/passwd -forever -rfbport 5900 -shared -noxdamage &\n\
# Start noVNC\n\
websockify --web=/usr/share/novnc 6080 localhost:5900 &\n\
wait\n' \
    > /start.sh && chmod +x /start.sh

EXPOSE 5900 6080

CMD ["/start.sh"]
