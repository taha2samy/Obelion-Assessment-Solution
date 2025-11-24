# ==========================================
# Data Sources
# ==========================================
data "aws_availability_zones" "available" {
  state = "available"


}

# # Fetch the latest fck-nat AMI (ARM64 for t4g instances)
# data "aws_ami" "fck_nat" {
#   most_recent = true
#   owners      = ["568608671756"]

#   filter {
#     name   = "name"
#     values = ["fck-nat-al2023-*-arm64-ebs"]
#   }
# }

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
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 1)
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags                    = { Name = "obelion-public-subnet" }
}

# 2. Private Subnet 1 (Primary)
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 4)
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = { Name = "obelion-private-subnet-1" }
}

# 3. Private Subnet 2 (Secondary)
resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 12)
  availability_zone = data.aws_availability_zones.available.names[2]
  tags              = { Name = "obelion-private-subnet-2" }
}


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
