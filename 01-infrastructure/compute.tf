resource "aws_key_pair" "deployer" {
  key_name   = "obelion-key"
  public_key = var.ssh_public_key
}

resource "aws_instance" "frontend" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.public.id # Public Subnet
  key_name      = aws_key_pair.deployer.key_name

  vpc_security_group_ids = [aws_security_group.frontend_sg.id]

  # Assign a Public IP (Explicitly requested in task)
  associate_public_ip_address = true

  # User Data to install Docker & Docker Compose
  user_data = file("${path.module}/scripts/frontend_setup.sh")

  # Root Block Device (8GB as requested)
  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }

  tags = {
    Name = "Obelion-Frontend-Server"
  }
}

# 2. Backend Server (Laravel PHP)
resource "aws_instance" "backend" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id # Public Subnet (as it has Public IP)
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.backend_sg.id]

  # Assign a Public IP (Explicitly requested in task)
  associate_public_ip_address = true

  # User Data to install Nginx, PHP, Composer, Git
  user_data = file("${path.module}/scripts/backend_setup.sh")

  # Root Block Device (8GB as requested)
  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }

  tags = {
    Name = "Obelion-Backend-Server"
  }



  user_data_replace_on_change = true

}
