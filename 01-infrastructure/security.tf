# ==========================================
# Security Groups
# ==========================================

# 1. NAT Instance SG (Already added previously, ensuring it's here)
resource "aws_security_group" "nat_sg" {
  name        = "obelion-nat-sg"
  description = "Security Group for fck-nat instance"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "obelion-nat-sg" }
}

# 2. Frontend Security Group
# Allows HTTP/HTTPS from anywhere, SSH from anywhere (or restricted IP)
resource "aws_security_group" "frontend_sg" {
  name        = "obelion-frontend-sg"
  description = "Security Group for Frontend Server"
  vpc_id      = aws_vpc.main.id

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Uptime Kuma default port (3001) - Optional if you expose it directly
  ingress {
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # In production, restrict this to your IP
  }

  # Outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "obelion-frontend-sg" }
}

# 3. Backend Security Group
# Allows SSH, and Traffic from Frontend if needed
resource "aws_security_group" "backend_sg" {
  name        = "obelion-backend-sg"
  description = "Security Group for Backend Server"
  vpc_id      = aws_vpc.main.id

  # HTTP (for API calls from Frontend or Public if it's a public API)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "obelion-backend-sg" }
}

# 4. Database Security Group
# STRICT: Only allows traffic from Backend SG on port 3306
resource "aws_security_group" "db_sg" {
  name        = "obelion-db-sg"
  description = "Security Group for RDS MySQL"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_sg.id] # Only Backend can access
  }

  tags = { Name = "obelion-db-sg" }
}
resource "aws_iam_role" "nat_role" {
  name = "obelion-nat-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# 2. The Policy (Permissions to edit Routes & ENI)
resource "aws_iam_policy" "nat_policy" {
  name = "obelion-nat-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:AttachNetworkInterface",
          "ec2:ModifyNetworkInterfaceAttribute",
          "ec2:AssociateAddress",
          "ec2:DisassociateAddress",
          "ec2:ReplaceRoute"
        ]
        Resource = "*"
      }
    ]
  })
}

# 3. Attach Policy to Role
resource "aws_iam_role_policy_attachment" "nat_attach" {
  role       = aws_iam_role.nat_role.name
  policy_arn = aws_iam_policy.nat_policy.arn
}

# 4. Instance Profile (To attach role to EC2)
resource "aws_iam_instance_profile" "nat_profile" {
  name = "obelion-nat-profile"
  role = aws_iam_role.nat_role.name
}
