# A disposable "fake VPS" for testing the playbook locally (lab 09):
# Ubuntu 24.04 with systemd and OpenSSH, like a fresh cloud server.
# Runs privileged so systemd, ufw (iptables), and Docker-in-Docker work;
# fake-vps.sh mounts volumes for /var/lib/docker (overlay can't nest on overlay).
# Never use this as a real server.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends systemd systemd-sysv openssh-server python3 sudo ca-certificates iproute2 \
 && rm -rf /var/lib/apt/lists/* \
 # Like a cloud image: root logs in with an SSH key on port 22.
 && mkdir -p /root/.ssh && chmod 700 /root/.ssh \
 && systemctl enable ssh

STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
