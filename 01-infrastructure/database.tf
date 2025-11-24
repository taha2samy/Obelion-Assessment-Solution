resource "aws_db_subnet_group" "default" {
  name       = "obelion-db-subnet-group"
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = {
    Name = "obelion-db-subnet-group"
  }
}

# 2. RDS MySQL Instance
resource "aws_db_instance" "default" {
  identifier        = "obelion-mysql"
  allocated_storage = 20
  storage_type      = "gp2"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.micro"

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  # Networking
  db_subnet_group_name   = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]

  # Critical: No Public Access
  publicly_accessible = false
  skip_final_snapshot = true
  tags = {
    Name = "Obelion-MySQL-DB"
  }
}
