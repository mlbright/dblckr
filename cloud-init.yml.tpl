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
runcmd:
  - systemctl enable --now tailscale-setup.service
