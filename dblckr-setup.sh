#!/bin/bash
set -e

# install Tailscale
#
# Only run this if we need to use this as an exit node.
# sysctl -p /etc/sysctl.d/99-tailscale.conf
#
curl -fsSL https://tailscale.com/install.sh | bash

export DEBIAN_FRONTEND=noninteractive

apt update
apt upgrade -y
apt install -y jq

# install cloudflared
mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared noble main' | tee /etc/apt/sources.list.d/cloudflared.list
apt update
apt install -y cloudflared
useradd -s /usr/sbin/nologin -r -M cloudflared
chown cloudflared:cloudflared /etc/default/cloudflared
chown cloudflared:cloudflared /usr/local/bin/cloudflared
systemctl enable --now cloudflared

# install pihole
curl -s -L https://install.pi-hole.net | bash /dev/stdin --unattended

# Update Pi-hole's lists
pihole -g
