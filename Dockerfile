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
    software-properties-common \
    --no-install-recommends && \
    add-apt-repository ppa:mozillateam/ppa -y && \
    echo 'Package: *\nPin: release o=LP-PPA-mozillateam\nPin-Priority: 1001' \
    > /etc/apt/preferences.d/mozilla-firefox && \
    apt-get update && \
    apt-get install -y --allow-downgrades firefox && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /root/.vnc && \
    x11vnc -storepasswd 1234 /root/.vnc/passwd

RUN echo '#!/bin/bash\n\
Xvfb :1 -screen 0 ${RESOLUTION} &\n\
sleep 1\n\
startxfce4 &\n\
sleep 2\n\
x11vnc -display :1 -rfbauth /root/.vnc/passwd -forever -rfbport 5900 -shared &\n\
websockify --web=/usr/share/novnc 6080 localhost:5900 &\n\
wait' > /start.sh && \
    chmod +x /start.sh

EXPOSE 5900 6080

CMD ["/start.sh"]
