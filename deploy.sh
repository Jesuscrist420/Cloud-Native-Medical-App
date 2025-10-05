#!/bin/bash
set -e

# Configuration
PROJECT_ID="proyecto-cloud-native"
REGION="us-central1"
REPO_NAME="medical-app"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse command line arguments
SKIP_BUILD=false
for arg in "$@"; do
  case $arg in
    --skip-build)
      SKIP_BUILD=true
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --skip-build    Skip building and pushing container images"
      echo "  --help, -h      Show this help message"
      echo ""
      echo "Example:"
      echo "  $0                  # Full deployment (build + infrastructure)"
      echo "  $0 --skip-build     # Deploy infrastructure only (skip container builds)"
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $arg${NC}"
      echo "Use --help to see available options"
      exit 1
      ;;
  esac
done

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}🚀 Cloud-Native Medical App Deployment${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

if [ "$SKIP_BUILD" = true ]; then
  echo -e "${BLUE}ℹ️  Skipping container builds (--skip-build flag enabled)${NC}"
  echo ""
fi

# Set project
echo -e "${YELLOW}📋 Setting GCP project...${NC}"
gcloud config set project $PROJECT_ID

# Build and push container images
SERVICES=("auth" "appointments" "payments" "notifications" "patients" "doctors" "reporting")

if [ "$SKIP_BUILD" = false ]; then
  echo ""
  echo -e "${YELLOW}🔨 Building and pushing container images...${NC}"

  for SERVICE in "${SERVICES[@]}"; do
  echo ""
  echo -e "${GREEN}Building ${SERVICE}...${NC}"
  
  # Create temporary cloudbuild.yaml for this service
  cat > /tmp/cloudbuild-${SERVICE}.yaml <<EOF
steps:
- name: 'gcr.io/cloud-builders/docker'
  args: ['build', '-t', '${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${SERVICE}:latest', '-f', 'services/${SERVICE}/Dockerfile', '.']
images:
- '${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${SERVICE}:latest'
EOF
  
  # Build from monorepo root with specific Dockerfile
  gcloud builds submit . \
    --config=/tmp/cloudbuild-${SERVICE}.yaml \
    --timeout=10m
    
  echo -e "${GREEN}✓ ${SERVICE} built and pushed${NC}"
done
else
  echo -e "${BLUE}⏭️  Container build phase skipped${NC}"
fi

echo ""
echo -e "${YELLOW}🏗️  Deploying infrastructure with Terraform...${NC}"

cd infra/terraform

# Initialize Terraform
terraform init

# Plan
terraform plan -var="project_id=${PROJECT_ID}" -var="region=${REGION}"

# Apply
echo ""
echo -e "${YELLOW}⚠️  Ready to deploy infrastructure. Continue? (y/n)${NC}"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  terraform apply -var="project_id=${PROJECT_ID}" -var="region=${REGION}" -auto-approve
  
  echo ""
  echo -e "${GREEN}================================${NC}"
  echo -e "${GREEN}✅ Deployment Complete!${NC}"
  echo -e "${GREEN}================================${NC}"
  
  # Show outputs
  terraform output deployment_summary
  
  echo ""
  echo -e "${YELLOW}📝 Service URLs have been saved to terraform.tfstate${NC}"
  echo -e "${YELLOW}   You can retrieve them with: terraform output service_urls${NC}"
  
else
  echo -e "${RED}Deployment cancelled${NC}"
  exit 1
fi

cd ../..

echo ""
echo -e "${GREEN}🧪 Next steps:${NC}"
echo -e "  1. Import the Postman collection: postman/Medical-App-E2E.postman_collection.json"
echo -e "  2. Update environment variables in Postman with service URLs"
echo -e "  3. Run the E2E appointment booking flow"
echo ""
