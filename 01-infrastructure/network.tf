

# ==========================================
# Data Sources
# ==========================================
data "aws_availability_zones" "available" {
  state = "available"
}

# Fetch the latest fck-nat AMI for ARM64 (cheaper t4g instances)
data "aws_ami" "fck_nat" {
  most_recent = true
  owners      = ["568608671756"] # Official fck-nat account ID

  filter {
    name   = "name"
    values = ["fck-nat-al2023-*-arm64-ebs"] # Using ARM64 for cost savings
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

# 1. Public Subnet (For Frontend, Backend & NAT Instance)
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true
  tags                    = { Name = "obelion-public-subnet" }
}

# 2. Private Subnet 1 (Primary for RDS)
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = var.availability_zone
  tags              = { Name = "obelion-private-subnet-1" }
}

# 3. Private Subnet 2 (Secondary for RDS Subnet Group Requirement)
resource "aws_subnet" "private_2" {
  vpc_id = aws_vpc.main.id
  # Calculate CIDR to avoid overlap (e.g., 10.0.12.0/24)
  cidr_block = cidrsubnet(var.vpc_cidr, 8, 12)
  # Use a different AZ
  availability_zone = data.aws_availability_zones.available.names[1]
  tags              = { Name = "obelion-private-subnet-2" }
}

# ==========================================
# fck-nat Instance (Custom NAT Solution)
# ==========================================
resource "aws_instance" "fck_nat" {
  ami           = data.aws_ami.fck_nat.id
  instance_type = "t4g.nano" # Very cheap ARM64 instance
  subnet_id     = aws_subnet.public.id

  # Attach the NAT Security Group (Defined in security.tf)
  vpc_security_group_ids = [aws_security_group.nat_sg.id]

  # Use the same key pair for SSH access if needed
  key_name = aws_key_pair.deployer.key_name

  # CRITICAL: Disable source/dest check to allow routing functionality
  source_dest_check = false

  tags = {
    Name = "obelion-fck-nat"
  }
}

# ==========================================
# Route Tables
# ==========================================

# 1. Public Route Table (To Internet Gateway)
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

# 2. Private Route Table (To fck-nat Instance)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    # Route internet traffic through the NAT instance
    network_interface_id = aws_instance.fck_nat.primary_network_interface_id
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
