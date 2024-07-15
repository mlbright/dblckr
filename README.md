# dblckr

> Ad blocker

## Overview

This repo configures a [Pi-hole][pihole] instance in [AWS][aws] to block ads and trackers in a [Tailscale][tailscale] network.
It achieves this by setting the Tailscale MagicDNS server to the Pi-hole instance, which is running on an EC2 instance in a private subnet.

The EC2 instance is a spot instance to save costs, and for resilience, it is configured in an Auto Scaling group so that terminated instances are replaced automatically.

DNS queries are forwarded by Pi-hole to [Cloudflare's][cloudflare] DNS over HTTPS (DoH) service.

## Contributing

Pull requests are welcome, but will be merged or closed at my sole discretion at any time.
If you find your pull request is closed and not merged, please feel free to fork the repository to make your own changes.

## Build the Pi-hole image

The Pi-hole image is built using [Packer](https://www.packer.io/).

```bash
packer init
packer fmt -check ./pihole.pkr.hcl
packer validate ./pihole.pkr.hcl
packer build ./pihole.pkr.hcl
```

Use this image as the value for the `pihole_ami_id` variable in `variables.tf` in the Terraform deployment.

## Deployment

The deployment is done via Terraform.
The Terraform state is stored in an S3 bucket via the s3 backend.

```bash
terraform init
terraform plan
terraform apply
```

The Terraform deployment can be done via GitHub Actions.
See the AWS documentation for more information on how to [set up the GitHub Actions workflow via OIDC][aws-github-actions-oidc].

## Observations

- As of `Sat Mar 29 14:29:57 EDT 2025`, the spot instance has been forcibly replaced by AWS only 5 times since the service started running in mid August 2024.
- The total cost of the service is less than $3.00 per month.
    - The tailnet has less than 10 devices and 1 user, where only 2 devices are heavily used at once.

## TODO

- [x] Update to Ubuntu 24.04 LTS
- [ ] Update to Graviton instance
- [x] Ensure forks cannot execute deployments
- [x] Run the Terraform from GitHub Actions
- [x] Update the docs
- [x] Add a license
- [x] Add contribution guidelines
- [x] Make the repo public
- [x] compute optimizer
- [x] IMDSv2


[pihole]: https://pi-hole.net/
[aws]: https://aws.amazon.com/
[tailscale]: https://tailscale.com/
[aws-github-actions-oidc]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-idp_oidc.html#idp_oidc_Create_GitHub
[cloudflare]: https://www.cloudflare.com/
