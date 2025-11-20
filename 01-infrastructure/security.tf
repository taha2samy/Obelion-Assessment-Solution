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
