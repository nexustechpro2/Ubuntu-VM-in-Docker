FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV MOZ_DISABLE_CONTENT_SANDBOX=1
ENV MOZ_NO_REMOTE=1
ENV MOZ_DISABLE_AUTO_SAFE_MODE=1

RUN apt update -y && apt install --no-install-recommends -y \
    xfce4 xfce4-goodies tigervnc-standalone-server novnc websockify \
    sudo xterm init systemd snapd vim net-tools curl wget git tzdata openssl

RUN apt update -y && apt install -y dbus-x11 x11-utils x11-xserver-utils x11-apps

RUN apt install -y software-properties-common

RUN add-apt-repository ppa:mozillateam/ppa -y

RUN echo 'Package: *' >> /etc/apt/preferences.d/mozilla-firefox && \
    echo 'Pin: release o=LP-PPA-mozillateam' >> /etc/apt/preferences.d/mozilla-firefox && \
    echo 'Pin-Priority: 1001' >> /etc/apt/preferences.d/mozilla-firefox && \
    echo 'Unattended-Upgrade::Allowed-Origins:: "LP-PPA-mozillateam:jammy";' | tee /etc/apt/apt.conf.d/51unattended-upgrades-firefox

RUN apt update -y && apt install -y firefox

RUN apt update -y && apt install -y xubuntu-icon-theme

# Firefox profile - single process, no sandbox, no crash loop
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

RUN touch /root/.Xauthority

EXPOSE 5901
EXPOSE 6080

CMD bash -c "vncserver -localhost no -SecurityTypes None -geometry 1024x768 --I-KNOW-THIS-IS-INSECURE && \
    openssl req -new -subj '/C=JP' -x509 -days 365 -nodes -out self.pem -keyout self.pem && \
    websockify -D --web=/usr/share/novnc/ --cert=self.pem 6080 localhost:5901 && \
    tail -f /dev/null"
