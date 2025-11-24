
TF_DIR=01-infrastructure
SSH_KEY_CONTENT := $(shell cat 05-keys/rsa.pub)
GITHUB_REPO_FRONTEND := taha2samy/uptime-kuma
FRONTEND_WORKFLOW_FILE := deploy-frontend.yml
BACKEND_WORKFLOW_FILE := deploy-backend.yml
GITHUB_REPO_BACKEND := "https://github.com/taha2samy/laravel"
export TF_VAR_ssh_public_key=$(SSH_KEY_CONTENT)
include .env
GREEN := \033[0;32m
NC := \033[0m

.PHONY: init plan apply destroy fmt validate output

init:
	@printf "$(GREEN)[+] Initializing Terraform...$(NC)\n"

	cd $(TF_DIR) && terraform init

plan:
	@printf "$(GREEN)[+] Running terraform plan...$(NC)"
	cd $(TF_DIR) && terraform plan
apply:
	@printf "$(GREEN)[+] Applying Terraform changes...$(NC)"
	cd $(TF_DIR) && terraform apply -auto-approve

destroy:
	printf "$(GREEN)[+] Destroying infrastructure...$(NC)"
	cd $(TF_DIR) && terraform destroy -auto-approve

fmt:
	@printf "$(GREEN)[+] Formatting Terraform files...$(NC)"
	cd $(TF_DIR) && terraform fmt

validate:
	@printf "$(GREEN)[+] Validating Terraform config...$(NC)"
	cd $(TF_DIR) && terraform validate

output:
	@printf "$(GREEN)[+] Showing Terraform outputs...$(NC)"
	cd $(TF_DIR) && terraform output
ssh-frontend:
	@printf "$(GREEN)[+] Connecting to Frontend Server...$(NC) \n"
	@chmod 400 05-keys/rsa
	@IP=$$(cd $(TF_DIR) && terraform output -raw frontend_public_ip); \
	echo "Connecting to ubuntu@$$IP ..."; \
	ssh -i 05-keys/rsa ubuntu@$$IP

ssh-backend:
	@printf "$(GREEN)[+] Connecting to Backend Server...$(NC) \n"
	@chmod 400 05-keys/rsa
	@IP=$$(cd $(TF_DIR) && terraform output -raw backend_public_ip); \
	echo "Connecting to ubuntu@$$IP ..."; \
	ssh -i 05-keys/rsa ubuntu@$$IP

gh-deploy-frontend:
	@printf "$(GREEN)[+] [Frontend] Fetching Configuration from Terraform...$(NC)\n"
	
	@# 1. Fetch values from Terraform
	$(eval FRONTEND_IP := $(shell cd $(TF_DIR) && terraform output -raw frontend_public_ip))
	$(eval FRONTEND_SSH_USER := $(shell cd $(TF_DIR) && terraform output -raw ssh_user_frontend))

	@printf "$(GREEN)[+] [Frontend] Uploading Secrets to GitHub Repo: $(GITHUB_REPO_FRONTEND)...$(NC)\n"
	
	@# 2. Upload Host IP
	@gh variable set FRONTEND_HOST --body "$(FRONTEND_IP)" --repo $(GITHUB_REPO_FRONTEND)
	@printf "   -> Secret 'FRONTEND_HOST' updated.\n"
	
	@# 3. Upload SSH User
	@gh secret set SSH_USER --body "$(FRONTEND_SSH_USER)" --repo $(GITHUB_REPO_FRONTEND)
	@printf "   -> Secret 'SSH_USER' updated.\n"

	@# 4. Upload Private Key
	@gh secret set SSH_PRIVATE_KEY < 05-keys/rsa --repo $(GITHUB_REPO_FRONTEND)
	@printf "   -> Secret 'SSH_PRIVATE_KEY' uploaded.\n"

	@printf "$(GREEN)[+] [Frontend] Triggering Workflow on $(GITHUB_REPO_FRONTEND)...$(NC)\n"
	
	@# 5. Trigger Workflow
	@gh workflow run $(FRONTEND_WORKFLOW_FILE) --ref master --repo $(GITHUB_REPO_FRONTEND)
	
	@printf "$(GREEN)[+] [Frontend] Workflow triggered! Watching status...$(NC)\n"
	@sleep 5
	
	@# 6. Watch Run
	@gh run watch --repo $(GITHUB_REPO_FRONTEND)
gh-deploy-backend:
	@printf "$(GREEN)[+] [Backend] Fetching Configuration from Terraform...$(NC)\n"
	
	@# 1. Fetch values from Terraform
	$(eval BACKEND_IP := $(shell cd $(TF_DIR) && terraform output -raw backend_public_ip))
	$(eval BACKEND_SSH_USER := $(shell cd $(TF_DIR) && terraform output -raw ssh_user_backend))
	$(eval DB_HOST := $(shell cd $(TF_DIR) && terraform output -raw db_endpoint))
	$(eval DB_NAME := $(shell cd $(TF_DIR) && terraform output -raw db_name))
	$(eval DB_USER := $(shell cd $(TF_DIR) && terraform output -raw db_username))
	$(eval DB_PASS := $(shell cd $(TF_DIR) && terraform output -raw db_password))

	@printf "$(GREEN)[+] [Backend] Uploading Secrets to GitHub Repo: $(GITHUB_REPO_BACKEND)...$(NC)\n"
	
	@# 2. Upload Backend Host IP (Variable)
	@gh variable set BACKEND_HOST --body "$(BACKEND_IP)" --repo $(GITHUB_REPO_BACKEND)
	
	@# 3. Upload SSH Config (Secrets)
	@gh secret set SSH_USER --body "$(BACKEND_SSH_USER)" --repo $(GITHUB_REPO_BACKEND)
	@gh secret set SSH_PRIVATE_KEY < 05-keys/rsa --repo $(GITHUB_REPO_BACKEND)

	@# 4. Upload Database Credentials (Secrets for .env)
	@gh secret set DB_HOST --body "$(DB_HOST)" --repo $(GITHUB_REPO_BACKEND)
	@gh secret set DB_DATABASE --body "$(DB_NAME)" --repo $(GITHUB_REPO_BACKEND)
	@gh secret set DB_USERNAME --body "$(DB_USER)" --repo $(GITHUB_REPO_BACKEND)
	@gh secret set DB_PASSWORD --body "$(DB_PASS)" --repo $(GITHUB_REPO_BACKEND)
	
	@printf "$(GREEN)[+] [Backend] Secrets Updated. Triggering Workflow...$(NC)\n"
	
	@# 5. Trigger Workflow
	@gh workflow run $(BACKEND_WORKFLOW_FILE) --ref "12.x" --repo $(GITHUB_REPO_BACKEND)
	
	@printf "$(GREEN)[+] [Backend] Workflow triggered! Watching status...$(NC)\n"
	@sleep 5
	@gh run watch --repo $(GITHUB_REPO_BACKEND)