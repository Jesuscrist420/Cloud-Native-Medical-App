#!/bin/bash
# Alternative installation script for macOS without Homebrew
# This script installs Terraform and jq manually

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Installing Prerequisites (without Homebrew)${NC}"
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo ""

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    ARCH_SUFFIX="arm64"
    echo -e "${GREEN}Detected: Apple Silicon (M1/M2/M3)${NC}"
else
    ARCH_SUFFIX="amd64"
    echo -e "${GREEN}Detected: Intel Mac${NC}"
fi

# Create temporary directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"
echo -e "${YELLOW}Working in temporary directory: $TEMP_DIR${NC}"
echo ""

# ============================================================
# Install Terraform
# ============================================================
echo -e "${YELLOW}1. Installing Terraform...${NC}"

TERRAFORM_VERSION="1.6.6"
TERRAFORM_ZIP="terraform_${TERRAFORM_VERSION}_darwin_${ARCH_SUFFIX}.zip"
TERRAFORM_URL="https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/${TERRAFORM_ZIP}"

echo "   Downloading Terraform ${TERRAFORM_VERSION}..."
if curl -Lo terraform.zip "$TERRAFORM_URL"; then
    echo -e "${GREEN}   ✓ Downloaded${NC}"
else
    echo -e "${RED}   ✗ Download failed${NC}"
    exit 1
fi

echo "   Extracting..."
unzip -q terraform.zip

echo "   Installing to /usr/local/bin..."
sudo mv terraform /usr/local/bin/
sudo chmod +x /usr/local/bin/terraform

# Verify installation
if terraform --version > /dev/null 2>&1; then
    INSTALLED_VERSION=$(terraform --version | head -n1)
    echo -e "${GREEN}   ✓ Terraform installed: $INSTALLED_VERSION${NC}"
else
    echo -e "${RED}   ✗ Terraform installation failed${NC}"
    exit 1
fi

echo ""

# ============================================================
# Install jq
# ============================================================
echo -e "${YELLOW}2. Installing jq...${NC}"

JQ_VERSION="1.7.1"
if [ "$ARCH" = "arm64" ]; then
    JQ_BINARY="jq-macos-arm64"
else
    JQ_BINARY="jq-macos-amd64"
fi
JQ_URL="https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/${JQ_BINARY}"

echo "   Downloading jq ${JQ_VERSION}..."
if curl -Lo jq "$JQ_URL"; then
    echo -e "${GREEN}   ✓ Downloaded${NC}"
else
    echo -e "${RED}   ✗ Download failed${NC}"
    exit 1
fi

echo "   Installing to /usr/local/bin..."
sudo mv jq /usr/local/bin/
sudo chmod +x /usr/local/bin/jq

# Verify installation
if jq --version > /dev/null 2>&1; then
    INSTALLED_VERSION=$(jq --version)
    echo -e "${GREEN}   ✓ jq installed: $INSTALLED_VERSION${NC}"
else
    echo -e "${RED}   ✗ jq installation failed${NC}"
    exit 1
fi

echo ""

# ============================================================
# Cleanup
# ============================================================
cd - > /dev/null
rm -rf "$TEMP_DIR"
echo -e "${GREEN}Cleanup complete${NC}"

echo ""
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ All tools installed successfully!${NC}"
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo ""
echo "Installed versions:"
echo "  • Terraform: $(terraform --version | head -n1 | awk '{print $2}')"
echo "  • jq: $(jq --version)"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Run: ./pre-deploy-check.sh"
echo "  2. Deploy: ./deploy.sh"
echo ""
