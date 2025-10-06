#!/bin/bash

# Quick Pub/Sub Verification Test
# Tests ONLY the working parts and Pub/Sub message flow

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

APPOINTMENTS_URL="https://appointments-667268984833.us-central1.run.app"
TIMESTAMP=$(date +%s)

echo -e "${BLUE}=== Pub/Sub Verification Test ===${NC}\n"

# Step 1: Create appointment (using the format that worked for you)
echo -e "${YELLOW}[1/4] Creating Appointment...${NC}"
APPOINTMENT_RESPONSE=$(curl -s -X POST "$APPOINTMENTS_URL/appointments" \
  -H "Content-Type: application/json" \
  -d "{
    \"appointment_id\": \"apt_${TIMESTAMP}\",
    \"patient_id\": \"patient_123\",
    \"doctor_id\": \"doctor_456\",
    \"datetime\": \"2025-10-15T10:00:00.000Z\",
    \"notes\": \"Test appointment for Pub/Sub verification\"
  }")

echo "$APPOINTMENT_RESPONSE" | jq .
echo ""

# Step 2: Check if message was published
echo -e "${YELLOW}[2/4] Checking Pub/Sub Topic...${NC}"
TOPIC_EXISTS=$(gcloud pubsub topics list --filter="name:appointments" --format="value(name)")
if [ -n "$TOPIC_EXISTS" ]; then
  echo -e "${GREEN}✓ Appointments topic exists${NC}"
else
  echo -e "${RED}✗ Appointments topic not found${NC}"
fi
echo ""

# Step 3: Check appointments service logs for Pub/Sub activity
echo -e "${YELLOW}[3/4] Checking Appointments Service Logs...${NC}"
echo "Looking for Pub/Sub initialization and publishing:"
gcloud logging read \
  'resource.type=cloud_run_revision 
   AND resource.labels.service_name=appointments 
   AND timestamp>="'$(date -u -v-5M +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "5 minutes ago" +%Y-%m-%dT%H:%M:%SZ)'"' \
  --limit=20 --format="value(timestamp,textPayload)" | grep -i "pub" | tail -5 || echo "  No Pub/Sub logs in last 5 minutes"
echo ""

# Step 4: Check notifications service logs
echo -e "${YELLOW}[4/4] Checking Notifications Service for Event Processing...${NC}"
echo "Looking for event processing:"
gcloud logging read \
  'resource.type=cloud_run_revision 
   AND resource.labels.service_name=notifications 
   AND timestamp>="'$(date -u -v-5M +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "5 minutes ago" +%Y-%m-%dT%H:%M:%SZ)'"' \
  --limit=20 --format="value(timestamp,textPayload)" | grep -E "(Received|Processing|appointment)" | tail -5 || echo "  No event processing logs in last 5 minutes"
echo ""

# Summary
echo -e "${BLUE}=== Summary ===${NC}"
echo -e "Appointment created: apt_${TIMESTAMP}"
echo ""
echo -e "${YELLOW}To verify Pub/Sub is working, you should see:${NC}"
echo "  1. ✓ 'Pub/Sub topic appointments ready' in appointments logs"
echo "  2. ✓ Event messages in notifications logs"
echo ""
echo -e "${YELLOW}If you see PERMISSION_DENIED:${NC}"
echo "  The permissions were just granted. Wait 60 seconds, then run:"
echo "  gcloud run services update appointments --region=us-central1 --update-env-vars=REFRESH=\$(date +%s)"
echo "  gcloud run services update notifications --region=us-central1 --update-env-vars=REFRESH=\$(date +%s)"
echo ""
echo -e "${YELLOW}Current Status:${NC}"
if gcloud logging read 'resource.labels.service_name=appointments AND textPayload=~"PERMISSION_DENIED"' --limit=1 --format="value(timestamp)" &>/dev/null; then
  echo -e "  ${RED}⚠ Permissions issue detected - services need restart${NC}"
else
  echo -e "  ${GREEN}✓ No recent permission errors${NC}"
fi
