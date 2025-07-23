#!/bin/bash
set -e

# In case we need to use this as an exit node
# sysctl -p /etc/sysctl.d/99-tailscale.conf

# Extract tailscale variables from /etc/dblckr/tailscale.json
tailscale_auth_key=$(jq -r '.tailscale_auth_key' /etc/dblckr/tailscale.json)
tailscale_api_key=$(jq -r '.tailscale_api_key' /etc/dblckr/tailscale.json)
tailscale_tailnet=$(jq -r '.tailscale_tailnet' /etc/dblckr/tailscale.json)

tailscale_device_name="pihole-$(echo $RANDOM | md5sum | cut -c1-6)"
tailscale up --authkey="${tailscale_auth_key}" --ssh --accept-dns=false --hostname="$tailscale_device_name"

# Set the DNS servers for the tailnet
ipv4=$(ip -j a | jq -r '.[] | select(.ifname == "tailscale0") | .addr_info | .[] | select(.family == "inet") | .local')
ipv6=$(ip -j a | jq -r '.[] | select(.ifname == "tailscale0") | .addr_info | .[] | select(.family == "inet6") | select(.scope == "global") | .local')

curl -s --request POST \
  --header "Authorization: Bearer ${tailscale_api_key}" \
  --header 'Content-Type: application/json' \
  --data @- \
  "https://api.tailscale.com/api/v2/tailnet/${tailscale_tailnet}/dns/nameservers" <<EOF
{
  "dns": [
    "$ipv4",
    "$ipv6"
  ]
}
EOF
