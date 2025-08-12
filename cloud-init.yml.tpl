#cloud-config
write_files:
- path: /etc/dblckr/tailscale.json
  permissions: '0644'
  owner: ubuntu:ubuntu
  content: |
    {
      "tailscale_auth_key": "${tailscale_auth_key}",
      "tailscale_api_key": "${tailscale_api_key}",
      "tailscale_tailnet": "${tailscale_tailnet}"
    }
- path: /etc/systemd/system/icrn.service.d/override.conf
  permissions: '0644'
  owner: root:root
  content: |
    [Service]
    Environment="NTFY_TOPIC=${NTFY_TOPIC}"
runcmd:
  - systemctl enable --now tailscale-setup.service
  - systemctl enable --now icrn
