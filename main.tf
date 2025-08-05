resource "aws_ec2_instance_connect_endpoint" "connect" {
  subnet_id          = aws_subnet.private["a"].id
  preserve_client_ip = false
  security_group_ids = [aws_security_group.ec2_connect_endpoint.id]
}

resource "aws_vpc" "adblocker" {
  assign_generated_ipv6_cidr_block = true
  cidr_block                       = var.vpc.cidr_block
  enable_dns_hostnames             = true
  enable_dns_support               = true
}

locals {
  zones = {
    "a" = 0
    "b" = 1
    "c" = 2
    "d" = 3
    "e" = 4
    "f" = 5
  }
}

resource "aws_subnet" "private" {
  for_each                        = var.private_subnets
  vpc_id                          = aws_vpc.adblocker.id
  cidr_block                      = each.value.ipv4_cidr
  ipv6_cidr_block                 = cidrsubnet(aws_vpc.adblocker.ipv6_cidr_block, 8, local.zones[each.key])
  assign_ipv6_address_on_creation = true
  availability_zone               = "${var.region}${each.key}"
}

resource "aws_egress_only_internet_gateway" "tailscale" {
  vpc_id = aws_vpc.adblocker.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.adblocker.id

  route {
    ipv6_cidr_block        = "::/0"
    egress_only_gateway_id = aws_egress_only_internet_gateway.tailscale.id
  }
}

resource "aws_route_table_association" "private" {
  for_each       = { for s in aws_subnet.private : s.availability_zone => s.id }
  subnet_id      = each.value
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "pihole" {
  name        = "adblocker"
  description = "Allow all outbound traffic and only SSH inbound"
  vpc_id      = aws_vpc.adblocker.id
}

resource "aws_vpc_security_group_egress_rule" "allow_all_ipv6" {
  security_group_id = aws_security_group.pihole.id
  description       = "Allow all outbound IPV6 traffic"
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "allow_all_ipv4" {
  security_group_id = aws_security_group.pihole.id
  description       = "Allow all outbound IPV4 traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "allow_inbound_ipv4_from_vpc" {
  security_group_id = aws_security_group.pihole.id
  description       = "Allow inbound traffic from VPC (IPv4)"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = aws_vpc.adblocker.cidr_block
}

resource "aws_autoscaling_group" "adblocker" {
  name_prefix         = "adblocker"
  vpc_zone_identifier = [for s in aws_subnet.private : s.id]
  launch_template {
    id      = aws_launch_template.adblocker.id
    version = aws_launch_template.adblocker.latest_version
  }

  min_size         = 1
  max_size         = 2
  desired_capacity = 1

  tag {
    key                 = "Name"
    value               = "adblocker"
    propagate_at_launch = true
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 100
    }
  }

  capacity_rebalance = true

  health_check_type = "EC2"

  availability_zone_distribution {
    capacity_distribution_strategy = "balanced-best-effort" # ... is the default
  }

  depends_on = [
    aws_egress_only_internet_gateway.tailscale,
    aws_route_table_association.private,
    aws_vpc_security_group_egress_rule.allow_all_ipv6,
  ]
}

resource "aws_launch_template" "adblocker" {
  name_prefix = "adblocker"

  image_id = var.pihole_ami_id

  instance_type = var.instance_type

  user_data = base64encode(templatefile("${path.module}/cloud-init.yml.tpl", {
    tailscale_auth_key = tailscale_tailnet_key.pre_authentication_key.key,
    tailscale_tailnet  = var.tailscale.tailnet,
    tailscale_api_key  = var.tailscale.api_key,
  }))

  vpc_security_group_ids = [aws_security_group.pihole.id]

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "adblocker"
    }
  }

  update_default_version = true

  instance_market_options {
    market_type = "spot"
    spot_options {
      instance_interruption_behavior = "terminate"
    }
  }
}

resource "tailscale_tailnet_key" "pre_authentication_key" {
  reusable      = true
  ephemeral     = true
  preauthorized = true
  expiry        = 7776000
  description   = "Pi-hole adblocker"
}

# The security group rules for an EC2 Instance Connect Endpoint must allow outbound traffic destined for the target instances to leave the endpoint.
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/eice-security-groups.html#resource-security-group-rules
resource "aws_security_group" "ec2_connect_endpoint" {
  name        = "instance_connect_endpoint"
  description = "Allow all outbound traffic from the EC2 instance connect endpoint service to the instances"
  vpc_id      = aws_vpc.adblocker.id
}

resource "aws_vpc_security_group_egress_rule" "allow_outbound_ipv4_ssh_from_endpoint_to_instances" {
  security_group_id = aws_security_group.ec2_connect_endpoint.id
  description       = "Allow outbound SSH traffic from the EC2 instance connect endpoint to the instances (IPv4)"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = aws_vpc.adblocker.cidr_block
}

resource "aws_vpc_security_group_egress_rule" "allow_outbound_ipv4_https_from_endpoint_to_instances" {
  security_group_id = aws_security_group.ec2_connect_endpoint.id
  description       = "Allow outbound https traffic from the EC2 instance connect endpoint to the instances (IPv4)"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = aws_vpc.adblocker.cidr_block
}
