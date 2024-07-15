variable "pihole_ami_id" {
  description = "The AMI to use for the Pihole instance"
  type        = string
}

variable "tags" {
  type = map(string)
  default = {
    Name = "adblocker"
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

variable "private_subnet" {
  type = object({
    cidr_block = string
  })
  default = {
    cidr_block = "10.0.1.0/28"
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
  default = "t3.micro"
}
