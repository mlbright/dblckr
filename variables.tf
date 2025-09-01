variable "pihole_ami_id" {
  description = "The AMI to use for the Pihole instance"
  type        = string
}

variable "tags" {
  type = map(string)
  default = {
    "deployment" = "adblocker"
  }
}

variable "vpc" {
  type = object({
    cidr_block = string
  })
  default = {
    cidr_block = "10.0.0.0/16"
  }
}

variable "private_subnets" {
  type = map(object({
    ipv4_cidr = string
  }))
  default = {
    "a" = {
      ipv4_cidr = "10.0.1.0/28"
    }
    "b" = {
      ipv4_cidr = "10.0.2.0/28"
    }
    "c" = {
      ipv4_cidr = "10.0.3.0/28"
    }
    "d" = {
      ipv4_cidr = "10.0.4.0/28"
    }
    "f" = {
      ipv4_cidr = "10.0.6.0/28"
    }
  }
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "tailscale" {
  type = object({
    api_key = string
    tailnet = string
  })
}

variable "instance_type" {
  type    = string
  default = "t4g.nano"
}

variable "ntfy" {
  type = object({
    topic = string
  })
}
