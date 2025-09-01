packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "pihole" {
  ami_name      = "pihole-linux-aws-{{uuid}}"
  instance_type = "t4g.nano"
  region        = "us-east-1"

  # Find AMI from https://cloud-images.ubuntu.com/locator/ec2/
  # Then use the AMI ID and run:
  # aws ec2 describe-images --filters "Name=image-id,Values=ami-0565c7ec71d5e8b8d" | grep -e Name -e Architecture -e OwnerId
  # https://stackoverflow.com/questions/75240350/packer-builder-source-ami-filter-for-ubuntu-22-04
  source_ami_filter {
    filters = {
      name = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-arm64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]
  }
  ssh_username = "ubuntu"
}

build {
  name = "pihole"
  sources = [
    "source.amazon-ebs.pihole"
  ]

  provisioner "file" {
    source      = "etc"
    destination = "/tmp"
  }

  provisioner "file" {
    source      = "usr"
    destination = "/tmp"
  }

  provisioner "file" {
    source      = "dblckr-setup.sh"
    destination = "/tmp/dblckr-setup.sh"
  }

  provisioner "shell" {
    inline = [
      "sudo rsync -av /tmp/etc/ /etc/",
      "sudo rsync -av /tmp/usr/ /usr/",
      "chmod +x /tmp/dblckr-setup.sh",
      "sudo /tmp/dblckr-setup.sh",
      "curl -L -o /tmp/icrn_0.1.10_arm64.deb https://github.com/mlbright/icrn/releases/download/v0.1.10/icrn_0.1.10_arm64.deb",
      "sudo apt install -y /tmp/icrn_0.1.10_arm64.deb",
    ]
  }
}
