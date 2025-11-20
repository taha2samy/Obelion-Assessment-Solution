#!/bin/bash

# Prevent interactive prompts during installation
export DEBIAN_FRONTEND=noninteractive

echo "🚀 Starting Frontend Setup..."

# 1. Update and Install Basic Tools
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# 2. Add Docker’s Official GPG Key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# 3. Set up the Repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 4. Install Docker Engine & Compose
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# 5. Enable and Start Docker
sudo systemctl enable docker
sudo systemctl start docker

# 6. Add 'ubuntu' user to docker group
# Allows running docker commands without sudo (required for GitHub Actions)
sudo usermod -aG docker ubuntu

# 7. Create Application Directory
# Pre-create directory for SCP action
mkdir -p /home/ubuntu/frontend
sudo chown ubuntu:ubuntu /home/ubuntu/frontend

echo "✅ Frontend Setup Complete!"