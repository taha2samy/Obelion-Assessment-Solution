# ==============================================================================
#  OBELION INFRASTRUCTURE AUTOMATION
# ==============================================================================

# --- Configuration & Variables ---
TF_DIR                  := 01-infrastructure
KEY_DIR                 := 05-keys
SSH_KEY_PRIVATE         := $(KEY_DIR)/rsa
SSH_KEY_PUBLIC          := $(KEY_DIR)/rsa.pub

# GitHub Configurations
GITHUB_REPO_FRONTEND    := taha2samy/uptime-kuma
FRONTEND_WORKFLOW       := deploy-frontend.yml
FRONTEND_BRANCH         := master

GITHUB_REPO_BACKEND     := taha2samy/laravel
BACKEND_WORKFLOW        := deploy-backend.yml
BACKEND_BRANCH          := 12.x

# Load Environment Variables (if .env exists)
ifneq (,$(wildcard .env))
    include .env
    export
endif

# Terraform Variables Injection
export TF_VAR_ssh_public_key = $(shell cat $(SSH_KEY_PUBLIC) 2>/dev/null)

# --- Colors ---
COLOR_RESET   := $(shell printf "\033[0m")
COLOR_GREEN   := $(shell printf "\033[0;32m")
COLOR_YELLOW  := $(shell printf "\033[0;33m")
COLOR_CYAN    := $(shell printf "\033[0;36m")

.PHONY: help init plan apply destroy fmt validate output ssh-frontend ssh-backend gh-deploy-frontend gh-deploy-backend keygen

# ==============================================================================
#  DEFAULT TARGET
# ==============================================================================

help: ## Show this help message
	@echo ""
	@echo "  $(COLOR_CYAN)Obelion Infrastructure Manager$(COLOR_RESET)"
	@echo "  Usage: make [target]"
	@echo ""
	@echo "  $(COLOR_YELLOW)Targets:$(COLOR_RESET)"
	@awk 'BEGIN {FS = ":.*##"; printf ""} /^[a-zA-Z_-]+:.*?##/ { printf "    $(COLOR_GREEN)%-25s$(COLOR_RESET) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""

# ==============================================================================
#  UTILITIES
# ==============================================================================

keygen: ## Generate SSH keys for the infrastructure (idempotent)
	@if [ -f "$(SSH_KEY_PRIVATE)" ]; then \
		echo "$(COLOR_YELLOW)[!] Keys already exist in $(KEY_DIR). Skipping...$(COLOR_RESET)"; \
	else \
		echo "$(COLOR_GREEN)[+] Generating new SSH Keys...$(COLOR_RESET)"; \
		ssh-keygen -t rsa -b 4096 -f $(SSH_KEY_PRIVATE) -N ""; \
		chmod 400 $(SSH_KEY_PRIVATE); \
		echo "$(COLOR_GREEN)[+] Keys generated successfully.$(COLOR_RESET)"; \
	fi

# ==============================================================================
#  TERRAFORM INFRASTRUCTURE
# ==============================================================================

init: ## Initialize Terraform (download providers/modules)
	@echo "$(COLOR_GREEN)[+] Initializing Terraform...$(COLOR_RESET)"
	@cd $(TF_DIR) && terraform init

plan: ## Show Terraform execution plan
	@echo "$(COLOR_GREEN)[+] Running terraform plan...$(COLOR_RESET)"
	@cd $(TF_DIR) && terraform plan

apply: ## Apply Terraform changes to create resources
	@echo "$(COLOR_GREEN)[+] Applying Terraform changes...$(COLOR_RESET)"
	@cd $(TF_DIR) && terraform apply -auto-approve

destroy: ## Destroy all Terraform resources
	@echo "$(COLOR_YELLOW)[!] DESTROYING INFRASTRUCTURE...$(COLOR_RESET)"
	@cd $(TF_DIR) && terraform destroy -auto-approve

fmt: ## Format Terraform files
	@echo "$(COLOR_GREEN)[+] Formatting Terraform files...$(COLOR_RESET)"
	@cd $(TF_DIR) && terraform fmt -recursive

validate: ## Validate Terraform configuration
	@echo "$(COLOR_GREEN)[+] Validating Terraform config...$(COLOR_RESET)"
	@cd $(TF_DIR) && terraform validate

output: ## Show Terraform outputs
	@cd $(TF_DIR) && terraform output

# ==============================================================================
#  SERVER ACCESS (SSH)
# ==============================================================================

ssh-frontend: ## SSH into the Frontend Server
	@echo "$(COLOR_GREEN)[+] Connecting to Frontend Server...$(COLOR_RESET)"
	@chmod 400 $(SSH_KEY_PRIVATE)
	@IP=$$(cd $(TF_DIR) && terraform output -raw frontend_public_ip); \
	echo "   -> Host: $$IP"; \
	ssh -o StrictHostKeyChecking=no -i $(SSH_KEY_PRIVATE) ubuntu@$$IP

ssh-backend: ## SSH into the Backend Server
	@echo "$(COLOR_GREEN)[+] Connecting to Backend Server...$(COLOR_RESET)"
	@chmod 400 $(SSH_KEY_PRIVATE)
	@IP=$$(cd $(TF_DIR) && terraform output -raw backend_public_ip); \
	echo "   -> Host: $$IP"; \
	ssh -o StrictHostKeyChecking=no -i $(SSH_KEY_PRIVATE) ubuntu@$$IP

# ==============================================================================
#  CI/CD & GITHUB ACTIONS
# ==============================================================================

gh-deploy-frontend: ## Sync Secrets & Trigger Frontend Deployment
	@echo "$(COLOR_CYAN)[+] [Frontend] Configuring GitHub Repo: $(GITHUB_REPO_FRONTEND)...$(COLOR_RESET)"
	
	@# 1. Fetch Terraform Outputs
	$(eval FRONTEND_IP := $(shell cd $(TF_DIR) && terraform output -raw frontend_public_ip))
	$(eval SSH_USER := $(shell cd $(TF_DIR) && terraform output -raw ssh_user_frontend))

	@# 2. Set Variables & Secrets
	@gh variable set FRONTEND_HOST --body "$(FRONTEND_IP)" --repo $(GITHUB_REPO_FRONTEND)
	@gh secret set SSH_USER --body "$(SSH_USER)" --repo $(GITHUB_REPO_FRONTEND)
	@gh secret set SSH_PRIVATE_KEY < $(SSH_KEY_PRIVATE) --repo $(GITHUB_REPO_FRONTEND)
	
	@echo "$(COLOR_GREEN)   -> Secrets updated successfully.$(COLOR_RESET)"

	@# 3. Trigger Workflow
	@echo "$(COLOR_CYAN)[+] Triggering Workflow: $(FRONTEND_WORKFLOW)...$(COLOR_RESET)"
	@gh workflow run $(FRONTEND_WORKFLOW) --ref $(FRONTEND_BRANCH) --repo $(GITHUB_REPO_FRONTEND)
	@sleep 3
	@gh run watch --repo $(GITHUB_REPO_FRONTEND)

gh-deploy-backend: ## Sync Secrets & Trigger Backend Deployment
	@echo "$(COLOR_CYAN)[+] [Backend] Configuring GitHub Repo: $(GITHUB_REPO_BACKEND)...$(COLOR_RESET)"
	
	@# 1. Fetch Terraform Outputs
	$(eval BACKEND_IP := $(shell cd $(TF_DIR) && terraform output -raw backend_public_ip))
	$(eval SSH_USER := $(shell cd $(TF_DIR) && terraform output -raw ssh_user_backend))
	$(eval DB_HOST := $(shell cd $(TF_DIR) && terraform output -raw db_endpoint))
	$(eval DB_NAME := $(shell cd $(TF_DIR) && terraform output -raw db_name))
	$(eval DB_USER := $(shell cd $(TF_DIR) && terraform output -raw db_username))
	$(eval DB_PASS := $(shell cd $(TF_DIR) && terraform output -raw db_password))

	@# 2. Set Variables & Secrets
	@gh variable set BACKEND_HOST --body "$(BACKEND_IP)" --repo $(GITHUB_REPO_BACKEND)
	@gh secret set SSH_USER --body "$(SSH_USER)" --repo $(GITHUB_REPO_BACKEND)
	@gh secret set SSH_PRIVATE_KEY < $(SSH_KEY_PRIVATE) --repo $(GITHUB_REPO_BACKEND)
	
	@# Database Secrets
	@gh secret set DB_HOST --body "$(DB_HOST)" --repo $(GITHUB_REPO_BACKEND)
	@gh secret set DB_DATABASE --body "$(DB_NAME)" --repo $(GITHUB_REPO_BACKEND)
	@gh secret set DB_USERNAME --body "$(DB_USER)" --repo $(GITHUB_REPO_BACKEND)
	@gh secret set DB_PASSWORD --body "$(DB_PASS)" --repo $(GITHUB_REPO_BACKEND)
	
	@echo "$(COLOR_GREEN)   -> Secrets updated successfully.$(COLOR_RESET)"
	
	@# 3. Trigger Workflow
	@echo "$(COLOR_CYAN)[+] Triggering Workflow: $(BACKEND_WORKFLOW)...$(COLOR_RESET)"
	@gh workflow run $(BACKEND_WORKFLOW) --ref $(BACKEND_BRANCH) --repo $(GITHUB_REPO_BACKEND)
	@sleep 3
	@gh run watch --repo $(GITHUB_REPO_BACKEND)