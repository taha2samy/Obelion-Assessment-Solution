# ========================================== 
# Database Resources (RDS MySQL) 
# ========================================== 
output "frontend_public_ip" {
  description = "Public IP of the Frontend Server"
  value       = aws_instance.frontend.public_ip
}

output "backend_public_ip" {
  description = "Public IP of the Backend Server"
  value       = aws_instance.backend.public_ip
}

output "db_endpoint" {
  description = "The connection endpoint for the RDS database"
  value       = aws_db_instance.default.endpoint
}

output "nat_public_ip" {
  description = "Public IP of the fck-nat Instance"
  value       = aws_instance.fck_nat.public_ip
}
