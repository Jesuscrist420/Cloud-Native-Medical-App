# 🛠️ Installation Guide - Without Homebrew

## Quick Install (Automated)

I've created a script that automatically installs Terraform and jq for you:

```bash
cd "Cloud-Native-Medical-App"

# Run the installation script
./install-tools.sh
```

**What it does:**
- ✅ Detects your Mac architecture (Apple Silicon or Intel)
- ✅ Downloads Terraform 1.6.6 from HashiCorp
- ✅ Downloads jq 1.7.1 from GitHub
- ✅ Installs both to `/usr/local/bin/`
- ✅ Verifies installations work correctly

**Note**: You'll be prompted for your password (sudo required for installation).

---

## Manual Installation (Alternative)

If you prefer to install manually:

### 1. Install Terraform

**For Apple Silicon (M1/M2/M3):**
```bash
cd ~/Downloads
curl -Lo terraform.zip https://releases.hashicorp.com/terraform/1.6.6/terraform_1.6.6_darwin_arm64.zip
unzip terraform.zip
sudo mv terraform /usr/local/bin/
sudo chmod +x /usr/local/bin/terraform
rm terraform.zip
terraform --version
```

**For Intel Mac:**
```bash
cd ~/Downloads
curl -Lo terraform.zip https://releases.hashicorp.com/terraform/1.6.6/terraform_1.6.6_darwin_amd64.zip
unzip terraform.zip
sudo mv terraform /usr/local/bin/
sudo chmod +x /usr/local/bin/terraform
rm terraform.zip
terraform --version
```

### 2. Install jq

**For Apple Silicon (M1/M2/M3):**
```bash
cd ~/Downloads
curl -Lo jq https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-macos-arm64
sudo mv jq /usr/local/bin/
sudo chmod +x /usr/local/bin/jq
jq --version
```

**For Intel Mac:**
```bash
cd ~/Downloads
curl -Lo jq https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-macos-amd64
sudo mv jq /usr/local/bin/
sudo chmod +x /usr/local/bin/jq
jq --version
```

---

## Verify Installation

After installation (automated or manual), verify everything is working:

```bash
# Check Terraform
terraform --version
# Expected: Terraform v1.6.6

# Check jq
jq --version
# Expected: jq-1.7.1

# Check gcloud (should already be installed)
gcloud --version
# Expected: Google Cloud SDK 540.0.0 (or similar)
```

---

## Next Steps

Once tools are installed:

```bash
# 1. Validate prerequisites
./pre-deploy-check.sh

# 2. If all checks pass, deploy
./deploy.sh
```

---

## Troubleshooting

### "Permission denied" error
```bash
# Ensure /usr/local/bin exists
sudo mkdir -p /usr/local/bin

# Add to PATH if needed
echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### "Command not found" after installation
```bash
# Reload your shell
source ~/.zshrc

# Or open a new terminal window
```

### "/usr/local/bin not writable"
```bash
# Fix permissions
sudo chown -R $(whoami) /usr/local/bin
```

### Download fails
If curl fails to download, try using a browser:
- Terraform: https://www.terraform.io/downloads
- jq: https://jqlang.github.io/jq/download/

Then move the downloaded files manually:
```bash
sudo mv ~/Downloads/terraform /usr/local/bin/
sudo mv ~/Downloads/jq /usr/local/bin/
sudo chmod +x /usr/local/bin/terraform
sudo chmod +x /usr/local/bin/jq
```

---

## Alternative: Use Docker (Advanced)

If you don't want to install anything locally, you can run deployment via Docker:

```bash
# Use Terraform Docker image
docker run -it --rm \
  -v "$PWD:/workspace" \
  -w /workspace/infra/terraform \
  hashicorp/terraform:1.6 init

# However, you'll still need gcloud CLI for authentication
```

---

## Why These Tools?

- **Terraform**: Infrastructure as Code tool to deploy all GCP resources
- **jq**: JSON processor to parse Terraform outputs and update Postman collection
- **gcloud**: Google Cloud CLI (you already have this installed)

---

## Ready?

Run this to get started:
```bash
./install-tools.sh
```

Then proceed with deployment! 🚀
