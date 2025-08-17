#!/bin/bash
set -euo pipefail

##### ENV #############
# Set the environment variables here
CLUSTER_NAME="devopsshack-cluster"
REGION="ap-south-1"
SERVICE_ACCOUNT_NAME="ebs-csi-controller-sa"
EBS_CSI_RELEASE="release-1.11"

echo "========================================="
echo "⚙️  EKS bootstrap for cluster: ${CLUSTER_NAME}"
echo "📍 Region: ${REGION}"
echo "========================================="

# Function to check if a command exists
need() { command -v "$1" >/dev/null 2>&1 || { echo "❌ '$1' not found. Please install it first."; exit 1; }; }

# ----------------------------------------
# Install prerequisites
# ----------------------------------------
echo "📦 Installing prerequisites..."
sudo apt-get update -y
sudo apt-get install -y curl unzip gnupg lsb-release

# ----------------------------------------
# Install AWS CLI
# ----------------------------------------
if ! command -v aws >/dev/null 2>&1; then
  echo "🟡 AWS CLI not found. Installing AWS CLI v2..."
  curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
  unzip -oq awscliv2.zip
  sudo ./aws/install
  rm -rf awscliv2.zip aws
else
  echo "✅ AWS CLI already installed: $(aws --version 2>&1)"
fi

# ----------------------------------------
# Install kubectl
# ----------------------------------------
if ! command -v kubectl >/dev/null 2>&1; then
  echo "🛠️  Installing kubectl..."
  KUBECTL_VER="$(curl -sL https://dl.k8s.io/release/stable.txt)"
  curl -LO "https://dl.k8s.io/release/${KUBECTL_VER}/bin/linux/amd64/kubectl"
  curl -LO "https://dl.k8s.io/release/${KUBECTL_VER}/bin/linux/amd64/kubectl.sha256"
  echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check - >/dev/null
  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  rm -f kubectl kubectl.sha256
else
  echo "✅ kubectl already installed: $(kubectl version --client --output=yaml | grep gitVersion | awk '{print $2}')"
fi

# ----------------------------------------
# Install eksctl
# ----------------------------------------
if ! command -v eksctl >/dev/null 2>&1; then
  echo "🛠️  Installing eksctl..."
  curl -sLO "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz"
  tar -xzf "eksctl_$(uname -s)_amd64.tar.gz"
  sudo mv eksctl /usr/local/bin/
  rm -f "eksctl_$(uname -s)_amd64.tar.gz"
else
  echo "✅ eksctl already installed: $(eksctl version)"
fi

# ----------------------------------------
# Configure kubeconfig
# ----------------------------------------
echo "☸️  Updating kubeconfig for cluster '${CLUSTER_NAME}'..."
aws eks --region "${REGION}" update-kubeconfig --name "${CLUSTER_NAME}" >/dev/null
kubectl config use-context "arn:aws:eks:${REGION}:$(aws sts get-caller-identity --query Account --output text):cluster/${CLUSTER_NAME}" || true
echo "✅ kubeconfig updated."

# ----------------------------------------
# Associate IAM OIDC Provider
# ----------------------------------------
echo "🔐 Associating IAM OIDC provider..."
eksctl utils associate-iam-oidc-provider \
  --region "${REGION}" \
  --cluster "${CLUSTER_NAME}" \
  --approve

# ----------------------------------------
# Create IAM Service Account for EBS CSI Driver
# ----------------------------------------
echo "🛡️  Creating IAM service account '${SERVICE_ACCOUNT_NAME}'..."
eksctl create iamserviceaccount \
  --region "${REGION}" \
  --name "${SERVICE_ACCOUNT_NAME}" \
  --namespace kube-system \
  --cluster "${CLUSTER_NAME}" \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --approve \
  --override-existing-serviceaccounts

# ----------------------------------------
# Deploy EBS CSI Driver
# ----------------------------------------
echo "📦 Deploying EBS CSI driver..."
kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/ecr/?ref=${EBS_CSI_RELEASE}"

# ----------------------------------------
# Deploy NGINX Ingress Controller
# ----------------------------------------
echo "🌐 Deploying NGINX Ingress Controller..."
kubectl apply -f "https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml"

# ----------------------------------------
# Deploy cert-manager
# ----------------------------------------
echo "🔒 Deploying cert-manager..."
kubectl apply -f "https://github.com/cert-manager/cert-manager/releases/download/v1.12.0/cert-manager.yaml"

# ----------------------------------------
# Wait for components to be ready (best-effort)
# ----------------------------------------
echo "⏳ Waiting for components to be ready..."
kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=180s || true
kubectl -n cert-manager rollout status deploy/cert-manager --timeout=180s || true
kubectl -n cert-manager rollout status deploy/cert-manager-webhook --timeout=180s || true
kubectl -n cert-manager rollout status deploy/cert-manager-cainjector --timeout=180s || true

echo "========================================="
echo "✅ EKS setup completed."
echo "➡️  Cluster: ${CLUSTER_NAME} | Region: ${REGION}"
echo "🔎 kubectl get nodes -o wide"
echo "🔎 kubectl get pods -A"
echo "========================================="
