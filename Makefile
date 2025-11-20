
TF_DIR=01-infrastructure
SSH_KEY_CONTENT := $(shell cat 05-keys/rsa.pub)

TF_VARS=terraform.tfvars
export TF_VAR_ssh_public_key=$(SSH_KEY_CONTENT)
export TF_VAR_db_password=admin
NC=\033[0m

.PHONY: init plan apply destroy fmt validate output

init:
	@echo "$(GREEN)[+] Initializing Terraform...$(NC)"
	cd $(TF_DIR) && terraform init

plan:
	@echo "$(GREEN)[+] Running terraform plan...$(NC)"
	cd $(TF_DIR) && terraform plan -var-file=$(TF_VARS)

apply:
	@echo "$(GREEN)[+] Applying Terraform changes...$(NC)"
	cd $(TF_DIR) && terraform apply -var-file=$(TF_VARS) -auto-approve

destroy:
	@echo "$(GREEN)[+] Destroying infrastructure...$(NC)"
	cd $(TF_DIR) && terraform destroy -var-file=$(TF_VARS) -auto-approve

fmt:
	@echo "$(GREEN)[+] Formatting Terraform files...$(NC)"
	cd $(TF_DIR) && terraform fmt

validate:
	@echo "$(GREEN)[+] Validating Terraform config...$(NC)"
	cd $(TF_DIR) && terraform validate

output:
	@echo "$(GREEN)[+] Showing Terraform outputs...$(NC)"
	cd $(TF_DIR) && terraform output