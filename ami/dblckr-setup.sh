#!/bin/bash
set -e

# install Tailscale
#
curl -fsSL https://tailscale.com/install.sh | bash

# Only run this if we need to use this as an exit node.
# sysctl -p /etc/sysctl.d/99-tailscale.conf

export DEBIAN_FRONTEND=noninteractive

apt update
apt upgrade -y
apt install -y jq

# install cloudflared
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64
sudo mv -f ./cloudflared-linux-arm64 /usr/local/bin/cloudflared
sudo chmod +x /usr/local/bin/cloudflared

useradd -s /usr/sbin/nologin -r -M cloudflared
chown cloudflared:cloudflared /etc/default/cloudflared
chown cloudflared:cloudflared /usr/local/bin/cloudflared
systemctl enable --now cloudflared

# install pihole
curl -s -L https://install.pi-hole.net | bash /dev/stdin --unattended

# Update Pi-hole's lists
pihole -g
