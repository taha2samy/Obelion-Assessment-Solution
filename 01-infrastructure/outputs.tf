# ========================================== 
# Database Resources (RDS MySQL) 
# ========================================== 
output "frontend_public_ip" {
  description = "Public IP of the Frontend Server"
  value       = aws_instance.frontend.public_ip
}

output "ssh_user_frontend" {
  description = "SSH user for the Frontend Server"
  value       = "ubuntu"
}


output "backend_public_ip" {
  description = "Public IP of the Backend Server"
  value       = aws_instance.backend.public_ip
}

output "ssh_user_backend" {
  description = "SSH user for the Backend Server"
  value       = "ubuntu"
}
output "db_name" {
  description = "Database name"
  value       = var.db_name
  sensitive   = true
}
output "db_username" {
  description = "Database username"
  value       = var.db_username
  sensitive   = true
}
output "db_password" {
  description = "Database password"
  value       = var.db_password
  sensitive   = true
}
output "db_endpoint" {
  description = "The connection endpoint for the RDS database"
  value       = aws_db_instance.default.endpoint
}

