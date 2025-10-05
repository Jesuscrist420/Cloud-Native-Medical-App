#!/bin/bash
set -e

# Configuration
PROJECT_ID="proyecto-cloud-native"
REGION="us-central1"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Setting environment variables for Cloud Run services...${NC}\n"

# Prompt for sensitive values
echo -e "${YELLOW}Please provide the following values:${NC}"
read -p "Cloud SQL Connection Name (format: PROJECT:REGION:INSTANCE): " SQL_CONNECTION_NAME
read -p "Database Password: " -s DB_PASSWORD
echo ""
read -p "JWT Secret (press enter to generate random): " JWT_SECRET

# Generate JWT secret if not provided
if [ -z "$JWT_SECRET" ]; then
  JWT_SECRET=$(openssl rand -base64 32)
  echo -e "${GREEN}Generated JWT Secret: $JWT_SECRET${NC}"
fi

# Extract Cloud SQL host from connection name
SQL_HOST="/cloudsql/${SQL_CONNECTION_NAME}"

echo -e "\n${GREEN}Updating Appointments Service...${NC}"
gcloud run services update appointments \
  --project=$PROJECT_ID \
  --region=$REGION \
  --set-env-vars="GOOGLE_CLOUD_PROJECT=${PROJECT_ID},DB_HOST=${SQL_HOST},DB_PORT=5432,DB_NAME=appointments_db,DB_USER=postgres,DB_PASSWORD=${DB_PASSWORD},TOPIC_APPOINTMENTS=appointments" \
  --add-cloudsql-instances=$SQL_CONNECTION_NAME \
  --no-traffic

echo -e "\n${GREEN}Updating Payments Service...${NC}"
gcloud run services update payments \
  --project=$PROJECT_ID \
  --region=$REGION \
  --set-env-vars="GOOGLE_CLOUD_PROJECT=${PROJECT_ID},DB_HOST=${SQL_HOST},DB_PORT=5432,DB_NAME=payments_db,DB_USER=postgres,DB_PASSWORD=${DB_PASSWORD},TOPIC_PAYMENTS=payments" \
  --add-cloudsql-instances=$SQL_CONNECTION_NAME \
  --no-traffic

echo -e "\n${GREEN}Updating Auth Service...${NC}"
gcloud run services update auth \
  --project=$PROJECT_ID \
  --region=$REGION \
  --set-env-vars="GOOGLE_CLOUD_PROJECT=${PROJECT_ID},JWT_SECRET=${JWT_SECRET}" \
  --no-traffic

echo -e "\n${GREEN}Updating Patients Service...${NC}"
gcloud run services update patients \
  --project=$PROJECT_ID \
  --region=$REGION \
  --set-env-vars="GOOGLE_CLOUD_PROJECT=${PROJECT_ID},PATIENTS_BUCKET=${PROJECT_ID}-patients-documents" \
  --no-traffic

echo -e "\n${GREEN}Updating Doctors Service...${NC}"
gcloud run services update doctors \
  --project=$PROJECT_ID \
  --region=$REGION \
  --set-env-vars="GOOGLE_CLOUD_PROJECT=${PROJECT_ID},DOCTORS_BUCKET=${PROJECT_ID}-doctors-documents" \
  --no-traffic

echo -e "\n${GREEN}Updating Reporting Service...${NC}"
gcloud run services update reporting \
  --project=$PROJECT_ID \
  --region=$REGION \
  --set-env-vars="GOOGLE_CLOUD_PROJECT=${PROJECT_ID},REPORTS_BUCKET=${PROJECT_ID}-reports" \
  --no-traffic

echo -e "\n${GREEN}Updating Notifications Service...${NC}"
gcloud run services update notifications \
  --project=$PROJECT_ID \
  --region=$REGION \
  --set-env-vars="GOOGLE_CLOUD_PROJECT=${PROJECT_ID},TOPIC_NOTIFICATIONS=notifications,SUB_NOTIFICATIONS=notifications-service" \
  --no-traffic

echo -e "\n${GREEN}✅ All environment variables set successfully!${NC}"
echo -e "\n${YELLOW}Important notes:${NC}"
echo -e "  • JWT Secret: ${JWT_SECRET}"
echo -e "  • Environment variables are set but not yet deployed"
echo -e "  • Run ${GREEN}./deploy.sh${NC} to deploy services with new configuration"
echo -e "\n${YELLOW}⚠️  The --no-traffic flag was used to prevent immediate deployment${NC}"
echo -e "    Services will get new env vars when you run ./deploy.sh${NC}"
