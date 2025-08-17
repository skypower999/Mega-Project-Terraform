#!/bin/bash
set -e

echo "=============================="
echo "🚀 Installing AWS CLI v2 & Terraform"
echo "=============================="

# ----------------------------------------
# Install Terraform
# ----------------------------------------
echo "📦 Installing Terraform..."
sudo apt-get update -y && sudo apt-get install -y gnupg software-properties-common curl

curl -fsSL https://apt.releases.hashicorp.com/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt-get update -y && sudo apt-get install terraform -y

# Verify Terraform installation
terraform -version

echo "=============================="
echo "✅ AWS CLI v2 & Terraform Installation Completed!"
echo "=============================="

# ----------------------------------------
# Install AWS CLI v2
# ----------------------------------------
echo "📦 Installing AWS CLI v2..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
sudo apt install unzip -y
unzip -o awscliv2.zip
sudo ./aws/install
rm -rf awscliv2.zip aws

# Verify AWS CLI installation
echo "✅ AWS CLI installed successfully!"
aws --version

# Configure AWS CLI
echo "🔧 Configuring AWS CLI..."
aws configure


