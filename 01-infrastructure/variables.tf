# ==========================================
# General Variables
# ==========================================
variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "The deployment environment"
  type        = string
  default     = "dev"
}

# ==========================================
# Network Variables
# ==========================================
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zone" {
  description = "The AZ to deploy resources in"
  type        = string
  default     = "eu-west-1"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the Public Subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the Private Subnet"
  type        = string
  default     = "10.0.2.0/24"
}

# ==========================================
# Compute Variables
# ==========================================
variable "instance_type" {
  description = "EC2 instance type for App Servers (Task: 1 Core, 1GB RAM)"
  type        = string
  default     = "t3.micro" # x86 Architecture
}
variable "ssh_public_key" {
  description = "Public key for SSH access"
  type        = string
  sensitive   = true
}


# ==========================================
# Database Variables
# ==========================================
variable "db_name" {
  description = "Name of the database"
  type        = string
  default     = "obelion_db"
}

variable "db_username" {
  description = "Database administrator username"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Database administrator password"
  type        = string
  sensitive   = true
}
