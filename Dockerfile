FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LIBGL_ALWAYS_SOFTWARE=1

# Install apt-utils first to suppress warnings
RUN apt update -y && apt install -y apt-utils

# Install desktop environment and VNC
RUN apt update -y && apt install --no-install-recommends -y \
    xfce4 xfce4-goodies tigervnc-standalone-server novnc websockify \
    sudo xterm init systemd snapd vim net-tools curl wget git tzdata

RUN apt install -y \
    dbus-x11 x11-utils x11-xserver-utils x11-apps

# Install Firefox from Mozilla Team PPA (non-snap)
RUN apt install -y software-properties-common
RUN add-apt-repository ppa:mozillateam/ppa -y

RUN echo 'Package: *' >> /etc/apt/preferences.d/mozilla-firefox && \
    echo 'Pin: release o=LP-PPA-mozillateam' >> /etc/apt/preferences.d/mozilla-firefox && \
    echo 'Pin-Priority: 1001' >> /etc/apt/preferences.d/mozilla-firefox

RUN echo 'Unattended-Upgrade::Allowed-Origins:: "LP-PPA-mozillateam:jammy";' | \
    tee /etc/apt/apt.conf.d/51unattended-upgrades-firefox

RUN apt update -y && apt install -y firefox
RUN apt update -y && apt install -y xubuntu-icon-theme

# Fix /dev/shm size (default 64MB is too small for Firefox — remount as 2GB)
RUN echo 'tmpfs /dev/shm tmpfs rw,nosuid,nodev,size=2g 0 0' >> /etc/fstab

# Disable GPU/hardware acceleration in Firefox (no GPU in cloud containers)
RUN mkdir -p /root/.mozilla/firefox/default && \
    echo 'user_pref("layers.acceleration.disabled", true);' >> /root/.mozilla/firefox/default/user.js && \
    echo 'user_pref("gfx.webrender.all", false);' >> /root/.mozilla/firefox/default/user.js && \
    echo 'user_pref("media.hardware-video-decoding.enabled", false);' >> /root/.mozilla/firefox/default/user.js && \
    echo 'user_pref("browser.tabs.remote.autostart", false);' >> /root/.mozilla/firefox/default/user.js

RUN touch /root/.Xauthority

EXPOSE 5901
EXPOSE 6080

# Remount /dev/shm to 2GB at startup, then launch VNC + noVNC
CMD bash -c "mount -o remount,size=2g /dev/shm && \
    vncserver -localhost no -SecurityTypes None -geometry 1024x768 --I-KNOW-THIS-IS-INSECURE && \
    openssl req -new -subj '/C=JP' -x509 -days 365 -nodes -out self.pem -keyout self.pem && \
    websockify -D --web=/usr/share/novnc/ --cert=self.pem 6080 localhost:5901 && \
    tail -f /dev/null"
