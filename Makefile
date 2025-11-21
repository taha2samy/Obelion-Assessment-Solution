
TF_DIR=01-infrastructure
SSH_KEY_CONTENT := $(shell cat 05-keys/rsa.pub)

TF_VARS=terraform.tfvars
export TF_VAR_ssh_public_key=$(SSH_KEY_CONTENT)
export TF_VAR_db_password=admin
GREEN := \033[0;32m
NC := \033[0m

.PHONY: init plan apply destroy fmt validate output

init:
	@printf "$(GREEN)[+] Initializing Terraform...$(NC)\n"

	cd $(TF_DIR) && terraform init

plan:
	@printf "$(GREEN)[+] Running terraform plan...$(NC)"
	cd $(TF_DIR) && terraform plan -var-file=$(TF_VARS)

apply:
	@printf "$(GREEN)[+] Applying Terraform changes...$(NC)"
	cd $(TF_DIR) && terraform apply -var-file=$(TF_VARS) -auto-approve

destroy:printf "$(GREEN)[+] Destroying infrastructure...$(NC)"
	cd $(TF_DIR) && terraform destroy -var-file=$(TF_VARS) -auto-approve

fmt:
	@printf "$(GREEN)[+] Formatting Terraform files...$(NC)"
	cd $(TF_DIR) && terraform fmt

validate:
	@printf "$(GREEN)[+] Validating Terraform config...$(NC)"
	cd $(TF_DIR) && terraform validate

output:
	@printf "$(GREEN)[+] Showing Terraform outputs...$(NC)"
	cd $(TF_DIR) && terraform output