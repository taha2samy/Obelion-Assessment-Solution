# ==========================================
# Data Sources
# ==========================================
data "aws_availability_zones" "available" {
  state = "available"
}

# Fetch the latest fck-nat AMI (ARM64 for t4g instances)
data "aws_ami" "fck_nat" {
  most_recent = true
  owners      = ["568608671756"]

  filter {
    name   = "name"
    values = ["fck-nat-al2023-*-arm64-ebs"]
  }
}

# ==========================================
# VPC & Internet Gateway
# ==========================================
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "obelion-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "obelion-igw" }
}

# ==========================================
# Subnets
# ==========================================

# 1. Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true
  tags                    = { Name = "obelion-public-subnet" }
}

# 2. Private Subnet 1 (Primary)
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = var.availability_zone
  tags              = { Name = "obelion-private-subnet-1" }
}

# 3. Private Subnet 2 (Secondary)
resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 12)
  availability_zone = data.aws_availability_zones.available.names[1]
  tags              = { Name = "obelion-private-subnet-2" }
}

# ==========================================
# HA NAT Instance Configuration
# ==========================================

# 1. Launch Template
resource "aws_launch_template" "nat_lt" {
  name_prefix   = "obelion-nat-lt-"
  image_id      = data.aws_ami.fck_nat.id
  instance_type = "t4g.nano"
  key_name      = aws_key_pair.deployer.key_name

  vpc_security_group_ids = [aws_security_group.nat_sg.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.nat_profile.name
  }

  # Inject variables into the external Bash script
  user_data = base64encode(templatefile("${path.module}/scripts/nat_bootstrap.sh", {
    region         = var.aws_region
    route_table_id = aws_route_table.private.id
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "obelion-ha-nat"
    }
  }
}

# 2. Auto Scaling Group
resource "aws_autoscaling_group" "nat_asg" {
  name                = "obelion-nat-asg"
  desired_capacity    = 1
  max_size            = 1
  min_size            = 1
  vpc_zone_identifier = [aws_subnet.public.id]

  launch_template {
    id      = aws_launch_template.nat_lt.id
    version = "$Latest"
  }

  health_check_type         = "EC2"
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "obelion-ha-nat"
    propagate_at_launch = true
  }
}

# ==========================================
# Route Tables
# ==========================================

# 1. Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "obelion-public-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# 2. Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  # NOTE: The route to 0.0.0.0/0 is managed dynamically by the NAT instance script.
  # We use ignore_changes to prevent Terraform from fighting with the script.
  lifecycle {
    ignore_changes = [route]
  }

  tags = { Name = "obelion-private-rt" }
}

resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}
