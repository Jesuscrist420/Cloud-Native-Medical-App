#!/bin/bash

# Complete Deployment Script - Deploy All Services with Latest Code
# This ensures: TypeScript compiled → Docker images built → Services deployed

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_ID="proyecto-cloud-native"
REGION="us-central1"
REGISTRY="us-central1-docker.pkg.dev/${PROJECT_ID}/medical-app"

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Complete Deployment - All Services        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}\n"

# ============================================
# STEP 1: Compile TypeScript
# ============================================
echo -e "${YELLOW}[1/4] Compiling TypeScript...${NC}"
echo "This ensures all your latest code changes are compiled to JavaScript"
echo ""

pnpm build

if [ $? -eq 0 ]; then
  echo -e "${GREEN}✓ TypeScript compilation successful${NC}\n"
else
  echo -e "${RED}✗ TypeScript compilation failed${NC}"
  exit 1
fi

# Verify compilation timestamps
echo -e "${BLUE}Verifying compilation:${NC}"
for service in auth appointments doctors patients payments reporting notifications; do
  if [ -f "services/$service/src/index.ts" ] && [ -f "services/$service/dist/index.js" ]; then
    SRC_TIME=$(stat -f %m "services/$service/src/index.ts" 2>/dev/null || stat -c %Y "services/$service/src/index.ts")
    DIST_TIME=$(stat -f %m "services/$service/dist/index.js" 2>/dev/null || stat -c %Y "services/$service/dist/index.js")
    
    if [ "$DIST_TIME" -ge "$SRC_TIME" ]; then
      echo -e "  ${GREEN}✓${NC} $service: dist is up-to-date"
    else
      echo -e "  ${RED}✗${NC} $service: WARNING - source is newer than compiled!"
    fi
  fi
done
echo ""

# ============================================
# STEP 2: Build and Push Docker Images (using Cloud Build)
# ============================================
echo -e "${YELLOW}[2/4] Building and Pushing Docker Images...${NC}"
echo "Using Cloud Build (no local Docker required)"
echo "Using --no-cache to ensure fresh builds"
echo ""

SERVICES=("auth" "appointments" "doctors" "patients" "payments" "reporting" "notifications")

for service in "${SERVICES[@]}"; do
  echo -e "${BLUE}Building $service...${NC}"
  
  # Create temporary cloudbuild.yaml for this service
  cat > /tmp/cloudbuild-${service}.yaml <<EOF
steps:
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'build'
      - '--no-cache'
      - '-t'
      - '${REGISTRY}/${service}:latest'
      - '-f'
      - 'services/${service}/Dockerfile'
      - '.'
images:
  - '${REGISTRY}/${service}:latest'
timeout: 900s
EOF
  
  # Build using Cloud Build
  gcloud builds submit . \
    --config=/tmp/cloudbuild-${service}.yaml \
    --timeout=15m \
    --quiet || {
    echo -e "${RED}✗ Failed to build $service${NC}"
    exit 1
  }
  
  echo -e "${GREEN}✓ $service built and pushed${NC}"
  echo -e "  Image: ${REGISTRY}/${service}:latest"
  echo ""
done

# ============================================
# STEP 3: Deploy to Cloud Run
# ============================================
echo -e "${YELLOW}[3/4] Deploying to Cloud Run...${NC}"
echo ""

cd infra/terraform

# Initialize Terraform if needed
if [ ! -d ".terraform" ]; then
  echo "Initializing Terraform..."
  terraform init
fi

# Apply Terraform changes
echo -e "${BLUE}Running terraform apply...${NC}"
terraform apply -auto-approve

if [ $? -eq 0 ]; then
  echo -e "${GREEN}✓ Terraform deployment successful${NC}\n"
else
  echo -e "${RED}✗ Terraform deployment failed${NC}"
  cd ../..
  exit 1
fi

cd ../..

# ============================================
# STEP 4: Force Service Updates (Ensure Latest Images)
# ============================================
echo -e "${YELLOW}[4/4] Forcing Service Updates...${NC}"
echo "This ensures Cloud Run pulls the latest Docker images"
echo ""

for service in "${SERVICES[@]}"; do
  echo -e "${BLUE}Updating $service...${NC}"
  
  gcloud run services update "$service" \
    --image="${REGISTRY}/${service}:latest" \
    --region="$REGION" \
    --platform=managed \
    --quiet || {
    echo -e "${YELLOW}⚠ Failed to update $service (may not exist yet)${NC}"
  }
  
  # Route 100% traffic to latest revision
  gcloud run services update-traffic "$service" \
    --to-latest \
    --region="$REGION" \
    --quiet 2>/dev/null || true
  
  echo -e "${GREEN}✓ $service updated${NC}\n"
done

# ============================================
# Verification
# ============================================
echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          Deployment Complete!                  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}\n"

echo -e "${YELLOW}Verifying deployments:${NC}\n"

for service in "${SERVICES[@]}"; do
  echo -n "  $service: "
  
  # Get latest revision
  REVISION=$(gcloud run services describe "$service" \
    --region="$REGION" \
    --format="value(status.latestReadyRevisionName)" 2>/dev/null || echo "not-found")
  
  if [ "$REVISION" != "not-found" ]; then
    # Get creation time
    CREATE_TIME=$(gcloud run revisions describe "$REVISION" \
      --region="$REGION" \
      --format="value(metadata.creationTimestamp)" 2>/dev/null || echo "unknown")
    
    echo -e "${GREEN}✓${NC} $REVISION (created: $CREATE_TIME)"
  else
    echo -e "${RED}✗ Not deployed${NC}"
  fi
done

echo ""
echo -e "${BLUE}Service URLs:${NC}"
for service in "${SERVICES[@]}"; do
  URL=$(gcloud run services describe "$service" \
    --region="$REGION" \
    --format="value(status.url)" 2>/dev/null || echo "Not available")
  echo -e "  $service: ${CYAN}$URL${NC}"
done

echo ""
echo -e "${GREEN}🎉 All services deployed with latest code!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Run: ${CYAN}./test-complete-e2e.sh${NC} to test the deployment"
echo -e "  2. Check logs: ${CYAN}gcloud run services logs read SERVICE_NAME --region=$REGION${NC}"
echo -e "  3. If Pub/Sub issues: ${CYAN}./fix-pubsub-permissions.sh${NC}"
