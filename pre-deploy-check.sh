#!/bin/bash
# Pre-deployment validation script
# Checks all prerequisites before running deploy.sh

# Don't exit on errors - we want to show all issues
# set -e

PROJECT_ID="proyecto-cloud-native"
REGION="us-central1"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CHECKS_PASSED=0
CHECKS_FAILED=0

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Pre-Deployment Validation Script         ║${NC}"
echo -e "${BLUE}║  Cloud-Native Medical App                  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

check_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((CHECKS_PASSED++))
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    ((CHECKS_FAILED++))
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo -e "${YELLOW}1. Checking Required Tools${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"

# Check gcloud
if command -v gcloud &> /dev/null; then
    GCLOUD_VERSION=$(gcloud --version | head -n1 | awk '{print $NF}')
    check_pass "gcloud CLI installed (version $GCLOUD_VERSION)"
else
    check_fail "gcloud CLI not found. Install: https://cloud.google.com/sdk/docs/install"
fi

# Check terraform
if command -v terraform &> /dev/null; then
    TERRAFORM_VERSION=$(terraform --version 2>/dev/null | head -n1 | awk '{print $2}' || echo "unknown")
    check_pass "Terraform installed (version $TERRAFORM_VERSION)"
else
    check_fail "Terraform not found. Run: ./install-tools.sh"
fi

# Check jq
if command -v jq &> /dev/null; then
    JQ_VERSION=$(jq --version 2>/dev/null || echo "unknown")
    check_pass "jq installed ($JQ_VERSION)"
else
    check_fail "jq not found. Run: ./install-tools.sh"
fi

# Check pnpm (for local development)
if command -v pnpm &> /dev/null; then
    PNPM_VERSION=$(pnpm --version)
    check_pass "pnpm installed (version $PNPM_VERSION)"
else
    check_warn "pnpm not found (needed for local dev). Install: npm install -g pnpm"
fi

echo ""
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo -e "${YELLOW}2. Checking GCP Authentication${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"

# Check gcloud auth
if gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
    ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
    check_pass "Authenticated as: $ACTIVE_ACCOUNT"
else
    check_fail "Not authenticated. Run: gcloud auth login"
fi

# Check application default credentials
if gcloud auth application-default print-access-token &> /dev/null 2>&1; then
    check_pass "Application default credentials configured"
else
    check_fail "Application default credentials not set. Run: gcloud auth application-default login"
fi

# Check current project
CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null)
if [ "$CURRENT_PROJECT" = "$PROJECT_ID" ]; then
    check_pass "GCP project set to: $PROJECT_ID"
else
    check_warn "Current project is '$CURRENT_PROJECT', expected '$PROJECT_ID'"
    echo "         Run: gcloud config set project $PROJECT_ID"
fi

echo ""
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo -e "${YELLOW}3. Checking GCP Project Configuration${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"

# Check if project exists
if gcloud projects describe $PROJECT_ID &> /dev/null; then
    check_pass "Project '$PROJECT_ID' exists"
    
    # Check billing with timeout to prevent hanging
    if timeout 10s gcloud beta billing projects describe $PROJECT_ID --format="value(billingEnabled)" 2>/dev/null | grep -q "True"; then
        check_pass "Billing enabled for project"
    else
        check_warn "Could not verify billing status (may need to check manually)"
        echo "         Verify at: https://console.cloud.google.com/billing"
    fi
else
    check_fail "Project '$PROJECT_ID' not found or no access"
fi

echo ""
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo -e "${YELLOW}4. Checking Required Permissions${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"

# Check IAM permissions (simplified check)
REQUIRED_ROLES=(
    "roles/run.admin"
    "roles/iam.serviceAccountAdmin"
    "roles/cloudsql.admin"
)

for role in "${REQUIRED_ROLES[@]}"; do
    # This is a basic check - in production you'd want more thorough validation
    check_warn "Ensure you have role: $role"
done

echo ""
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo -e "${YELLOW}5. Checking Project Structure${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"

# Check critical files exist
REQUIRED_FILES=(
    "infra/terraform/main.tf"
    "infra/terraform/variables.tf"
    "infra/terraform/outputs.tf"
    "services/auth/Dockerfile"
    "services/appointments/Dockerfile"
    "services/payments/Dockerfile"
    "services/notifications/Dockerfile"
    "services/patients/Dockerfile"
    "services/doctors/Dockerfile"
    "services/reporting/Dockerfile"
    "deploy.sh"
    "update-postman.sh"
    "health-check.sh"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        check_pass "Found: $file"
    else
        check_fail "Missing: $file"
    fi
done

echo ""
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo -e "${YELLOW}6. Checking Service Implementations${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"

SERVICES=("auth" "appointments" "payments" "notifications" "patients" "doctors" "reporting")

for service in "${SERVICES[@]}"; do
    if [ -f "services/$service/src/index.ts" ]; then
        check_pass "Service implementation: $service"
    else
        check_fail "Missing implementation: services/$service/src/index.ts"
    fi
done

echo ""
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo -e "${YELLOW}7. Checking Terraform Configuration${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"

cd infra/terraform

# Check terraform init
if [ -d ".terraform" ]; then
    check_pass "Terraform initialized"
else
    check_warn "Terraform not initialized. Will run during deployment"
fi

# Validate terraform syntax
if terraform validate &> /dev/null; then
    check_pass "Terraform configuration valid"
else
    check_fail "Terraform configuration has errors"
    terraform validate
fi

cd ../..

echo ""
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo -e "${YELLOW}8. Estimating Deployment Time & Costs${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"

echo -e "${BLUE}Estimated Deployment Time:${NC}"
echo "  - Container builds (7 services): ~10-15 minutes"
echo "  - Terraform infrastructure: ~5-10 minutes"
echo "  - Total: ~15-25 minutes"
echo ""
echo -e "${BLUE}Estimated Monthly Costs (Development):${NC}"
echo "  - Cloud Run (light usage): ~\$5-10"
echo "  - Cloud SQL (db-f1-micro): ~\$7"
echo "  - Firestore (light usage): Free tier"
echo "  - Cloud Storage: ~\$1-2"
echo "  - Pub/Sub: Free tier"
echo "  - Total: ~\$15-20/month"

echo ""
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo -e "${YELLOW}Summary${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"

echo -e "${GREEN}Passed: $CHECKS_PASSED${NC}"
echo -e "${RED}Failed: $CHECKS_FAILED${NC}"

echo ""

if [ $CHECKS_FAILED -gt 0 ]; then
    echo -e "${RED}⚠️  Validation FAILED${NC}"
    echo -e "${RED}Please fix the issues above before deploying${NC}"
    echo ""
    exit 1
else
    echo -e "${GREEN}✓ All critical checks passed!${NC}"
    echo ""
    echo -e "${BLUE}Ready to deploy. Run:${NC}"
    echo -e "${GREEN}  ./deploy.sh${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  Important Notes:${NC}"
    echo "  1. Deployment will incur GCP costs"
    echo "  2. Resources will be publicly accessible (no API Gateway)"
    echo "  3. Database schemas need manual creation after deployment"
    echo "  4. Review INFRASTRUCTURE.md for post-deployment tasks"
    echo ""
fi
