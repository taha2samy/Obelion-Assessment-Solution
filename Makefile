# ============================
# Bootstrap Makefile
# ============================

# Current Directory
TF_DIR=.

GREEN=\033[0;32m
NC=\033[0m

.PHONY: init plan apply destroy fmt validate output

init:
	@echo "$(GREEN)[+] Initializing Terraform (Local State)...$(NC)"
	terraform init

plan:
	@echo "$(GREEN)[+] Running terraform plan...$(NC)"
	terraform plan

apply:
	@echo "$(GREEN)[+] Applying Terraform changes...$(NC)"
	terraform apply -auto-approve

destroy:
	@echo "$(GREEN)[+] Destroying infrastructure...$(NC)"
	terraform destroy -auto-approve

fmt:
	@echo "$(GREEN)[+] Formatting Terraform files...$(NC)"
	terraform fmt

validate:
	@echo "$(GREEN)[+] Validating Terraform config...$(NC)"
	terraform validate

output:
	@echo "$(GREEN)[+] Showing Terraform outputs...$(NC)"
	terraform output