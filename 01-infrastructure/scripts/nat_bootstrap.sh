#!/bin/bash

# Variables injected by Terraform templatefile function
REGION="${region}"
ROUTE_TABLE_ID="${route_table_id}"

# Get current Instance ID
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

echo " Starting NAT Bootstrap for Instance: $INSTANCE_ID"

# ==========================================
# 1. Install AWS CLI (If not exists)
# ==========================================
if ! command -v aws &> /dev/null
then
    echo "AWS CLI not found. Installing..."
    
    # Install dependencies (unzip & curl) based on OS
    if [ -f /etc/debian_version ]; then
        # Ubuntu / Debian
        sudo apt-get update -y
        sudo apt-get install -y unzip curl
    elif [ -f /etc/redhat-release ]; then
        # Amazon Linux / RHEL / CentOS
        sudo yum update -y
        sudo yum install -y unzip curl
    fi

    # Download AWS CLI v2 for ARM64 (Since we use t4g instances)
    curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
    
    unzip -q awscliv2.zip
    sudo ./aws/install
    
    # Cleanup
    rm -rf aws awscliv2.zip
    
    echo "✅ AWS CLI Installed successfully."
else
    echo "✅ AWS CLI is already installed."
fi

# ==========================================
# 2. Configure Routing
# ==========================================

echo "Configuring Network Attributes..."

# Disable Source/Destination Check
aws ec2 modify-network-interface-attribute \
    --instance-id $INSTANCE_ID \
    --no-source-dest-check \
    --region $REGION

# Update the Route Table
echo "Updating Route Table: $ROUTE_TABLE_ID ..."

aws ec2 replace-route \
    --route-table-id $ROUTE_TABLE_ID \
    --destination-cidr-block 0.0.0.0/0 \
    --instance-id $INSTANCE_ID \
    --region $REGION

echo "🎉 NAT Configuration Complete!"