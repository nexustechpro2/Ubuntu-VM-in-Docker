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
    software-properties-common \
    --no-install-recommends

# Add Mozilla PPA manually
RUN curl -fsSL https://keyserver.ubuntu.com/pks/lookup?op=get\&search=0x738BEB9321D1AAEC13EA9391AEBDF4819BE21867 \
    | gpg --dearmor -o /etc/apt/trusted.gpg.d/mozillateam-ppa.gpg && \
    echo "deb https://ppa.launchpadcontent.net/mozillateam/ppa/ubuntu jammy main" \
    > /etc/apt/sources.list.d/mozillateam.list && \
    printf 'Package: *\nPin: release o=LP-PPA-mozillateam\nPin-Priority: 1001\n' \
    > /etc/apt/preferences.d/mozilla-firefox

RUN apt-get update && apt-get install -y --allow-downgrades firefox

RUN apt-get clean && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /root/.vnc && \
    x11vnc -storepasswd 1234 /root/.vnc/passwd

RUN printf '#!/bin/bash\nXvfb :1 -screen 0 ${RESOLUTION} &\nsleep 1\nstartxfce4 &\nsleep 2\nx11vnc -display :1 -rfbauth /root/.vnc/passwd -forever -rfbport 5900 -shared &\nwebsockify --web=/usr/share/novnc 6080 localhost:5900 &\nwait\n' \
    > /start.sh && chmod +x /start.sh

EXPOSE 5900 6080

CMD ["/start.sh"]
