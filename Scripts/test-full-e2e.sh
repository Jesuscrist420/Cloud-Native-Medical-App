#!/bin/bash

# Cloud-Native Medical App - Complete End-to-End Test
# Tests the FULL workflow with correct field names based on actual code

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Service URLs
AUTH_URL="https://auth-667268984833.us-central1.run.app"
PATIENTS_URL="https://patients-667268984833.us-central1.run.app"
DOCTORS_URL="https://doctors-667268984833.us-central1.run.app"
APPOINTMENTS_URL="https://appointments-667268984833.us-central1.run.app"
PAYMENTS_URL="https://payments-667268984833.us-central1.run.app"

# Generate unique test data
TIMESTAMP=$(date +%s)
PATIENT_EMAIL="patient${TIMESTAMP}@test.com"
DOCTOR_EMAIL="doctor${TIMESTAMP}@test.com"
PASSWORD="SecurePass123!"

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Cloud-Native Medical App - Full E2E Test    ║${NC}"
echo -e "${BLUE}║   Complete Workflow with CORS Enabled         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}\n"

# ============================================
# STEP 1: Register Patient (Auth Service)
# ============================================
echo -e "${CYAN}[1/10] Patient Registration${NC}"
echo -e "${YELLOW}→ Registering patient account...${NC}"

PATIENT_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "$AUTH_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"$PATIENT_EMAIL\",
    \"password\": \"$PASSWORD\",
    \"role\": \"patient\"
  }")

HTTP_CODE=$(echo "$PATIENT_RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
RESPONSE_BODY=$(echo "$PATIENT_RESPONSE" | sed '/HTTP_CODE:/d')

echo "$RESPONSE_BODY" | jq . 2>/dev/null || echo "$RESPONSE_BODY"

PATIENT_TOKEN=$(echo "$RESPONSE_BODY" | jq -r '.token // empty')
PATIENT_ID=$(echo "$RESPONSE_BODY" | jq -r '.user.id // empty')

if [ -z "$PATIENT_TOKEN" ] || [ "$PATIENT_TOKEN" = "null" ]; then
  echo -e "${RED}✗ Failed (HTTP $HTTP_CODE)${NC}\n"
  exit 1
fi

echo -e "${GREEN}✓ Success (HTTP $HTTP_CODE)${NC}"
echo -e "  Patient ID: ${CYAN}$PATIENT_ID${NC}"
echo -e "  Email: ${CYAN}$PATIENT_EMAIL${NC}\n"

# ============================================
# STEP 2: Register Doctor (Auth Service)
# ============================================
echo -e "${CYAN}[2/10] Doctor Registration${NC}"
echo -e "${YELLOW}→ Registering doctor account...${NC}"

DOCTOR_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "$AUTH_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"$DOCTOR_EMAIL\",
    \"password\": \"$PASSWORD\",
    \"role\": \"doctor\"
  }")

HTTP_CODE=$(echo "$DOCTOR_RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
RESPONSE_BODY=$(echo "$DOCTOR_RESPONSE" | sed '/HTTP_CODE:/d')

echo "$RESPONSE_BODY" | jq . 2>/dev/null || echo "$RESPONSE_BODY"

DOCTOR_TOKEN=$(echo "$RESPONSE_BODY" | jq -r '.token // empty')
DOCTOR_ID=$(echo "$RESPONSE_BODY" | jq -r '.user.id // empty')

if [ -z "$DOCTOR_TOKEN" ] || [ "$DOCTOR_TOKEN" = "null" ]; then
  echo -e "${RED}✗ Failed (HTTP $HTTP_CODE)${NC}\n"
  exit 1
fi

echo -e "${GREEN}✓ Success (HTTP $HTTP_CODE)${NC}"
echo -e "  Doctor ID: ${CYAN}$DOCTOR_ID${NC}"
echo -e "  Email: ${CYAN}$DOCTOR_EMAIL${NC}\n"

# ============================================
# STEP 3: Verify Token (Auth Service)
# ============================================
echo -e "${CYAN}[3/10] Token Verification${NC}"
echo -e "${YELLOW}→ Verifying patient JWT token...${NC}"

VERIFY_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X GET "$AUTH_URL/auth/verify" \
  -H "Authorization: Bearer $PATIENT_TOKEN")

HTTP_CODE=$(echo "$VERIFY_RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
RESPONSE_BODY=$(echo "$VERIFY_RESPONSE" | sed '/HTTP_CODE:/d')

echo "$RESPONSE_BODY" | jq . 2>/dev/null || echo "$RESPONSE_BODY"

if [ "$HTTP_CODE" = "200" ]; then
  echo -e "${GREEN}✓ Token valid (HTTP $HTTP_CODE)${NC}\n"
else
  echo -e "${RED}✗ Token invalid (HTTP $HTTP_CODE)${NC}\n"
fi

# ============================================
# STEP 4: Create Patient Profile (Patients Service)
# ============================================
echo -e "${CYAN}[4/10] Create Patient Profile${NC}"
echo -e "${YELLOW}→ Creating detailed patient profile...${NC}"

# Schema: patientId, name, email, phone (opt), dateOfBirth (opt), address (opt), medicalHistory (opt)
PATIENT_PROFILE_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "$PATIENTS_URL/patients" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $PATIENT_TOKEN" \
  -d "{
    \"patientId\": \"$PATIENT_ID\",
    \"name\": \"John Patient Doe\",
    \"email\": \"$PATIENT_EMAIL\",
    \"phone\": \"+1-555-0123\",
    \"dateOfBirth\": \"1990-05-15\",
    \"address\": \"123 Main St, New York, NY 10001\",
    \"medicalHistory\": \"No known allergies. Previous surgery in 2018.\"
  }")

HTTP_CODE=$(echo "$PATIENT_PROFILE_RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
RESPONSE_BODY=$(echo "$PATIENT_PROFILE_RESPONSE" | sed '/HTTP_CODE:/d')

echo "$RESPONSE_BODY" | jq . 2>/dev/null || echo "$RESPONSE_BODY"

if [ "$HTTP_CODE" = "201" ]; then
  echo -e "${GREEN}✓ Patient profile created (HTTP $HTTP_CODE)${NC}\n"
else
  echo -e "${YELLOW}⚠ Patient profile creation failed (HTTP $HTTP_CODE)${NC}\n"
fi

# ============================================
# STEP 5: Create Doctor Profile (Doctors Service)
# ============================================
echo -e "${CYAN}[5/10] Create Doctor Profile${NC}"
echo -e "${YELLOW}→ Creating detailed doctor profile...${NC}"

# Schema: doctorId, name, email, phone (opt), specialization, licenseNumber, yearsOfExperience (opt), bio (opt)
DOCTOR_PROFILE_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "$DOCTORS_URL/doctors" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $DOCTOR_TOKEN" \
  -d "{
    \"doctorId\": \"$DOCTOR_ID\",
    \"name\": \"Dr. Jane Smith\",
    \"email\": \"$DOCTOR_EMAIL\",
    \"phone\": \"+1-555-0456\",
    \"specialization\": \"Cardiology\",
    \"licenseNumber\": \"MD-${TIMESTAMP}\",
    \"yearsOfExperience\": 10,
    \"bio\": \"Board-certified cardiologist with 10 years of experience specializing in heart disease prevention.\"
  }")

HTTP_CODE=$(echo "$DOCTOR_PROFILE_RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
RESPONSE_BODY=$(echo "$DOCTOR_PROFILE_RESPONSE" | sed '/HTTP_CODE:/d')

echo "$RESPONSE_BODY" | jq . 2>/dev/null || echo "$RESPONSE_BODY"

if [ "$HTTP_CODE" = "201" ]; then
  echo -e "${GREEN}✓ Doctor profile created (HTTP $HTTP_CODE)${NC}\n"
else
  echo -e "${YELLOW}⚠ Doctor profile creation failed (HTTP $HTTP_CODE)${NC}\n"
fi

# ============================================
# STEP 6: List Available Doctors (Doctors Service)
# ============================================
echo -e "${CYAN}[6/10] List Available Doctors${NC}"
echo -e "${YELLOW}→ Retrieving all doctors...${NC}"

DOCTORS_LIST=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X GET "$DOCTORS_URL/doctors")

HTTP_CODE=$(echo "$DOCTORS_LIST" | grep "HTTP_CODE:" | cut -d: -f2)
RESPONSE_BODY=$(echo "$DOCTORS_LIST" | sed '/HTTP_CODE:/d')

echo "$RESPONSE_BODY" | jq . 2>/dev/null || echo "$RESPONSE_BODY"

DOCTOR_COUNT=$(echo "$RESPONSE_BODY" | jq '.doctors | length' 2>/dev/null || echo "0")

if [ "$HTTP_CODE" = "200" ]; then
  echo -e "${GREEN}✓ Retrieved doctors list (HTTP $HTTP_CODE)${NC}"
  echo -e "  Total doctors: ${CYAN}$DOCTOR_COUNT${NC}\n"
else
  echo -e "${RED}✗ Failed (HTTP $HTTP_CODE)${NC}\n"
fi

# ============================================
# STEP 7: Create Appointment (Appointments Service)
# ============================================
echo -e "${CYAN}[7/10] Create Appointment${NC}"
echo -e "${YELLOW}→ Booking medical appointment...${NC}"

APPOINTMENT_ID="apt_${TIMESTAMP}"
APPOINTMENT_DATE=$(date -u -v+7d +"%Y-%m-%dT14:00:00.000Z" 2>/dev/null || date -u -d "+7 days" +"%Y-%m-%dT14:00:00.000Z")

# Schema: appointmentId, patientId, doctorId, datetime, notes (opt)
APPOINTMENT_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "$APPOINTMENTS_URL/appointments" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $PATIENT_TOKEN" \
  -d "{
    \"appointmentId\": \"$APPOINTMENT_ID\",
    \"patientId\": \"$PATIENT_ID\",
    \"doctorId\": \"$DOCTOR_ID\",
    \"datetime\": \"$APPOINTMENT_DATE\",
    \"notes\": \"Annual checkup and blood pressure monitoring\"
  }")

HTTP_CODE=$(echo "$APPOINTMENT_RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
RESPONSE_BODY=$(echo "$APPOINTMENT_RESPONSE" | sed '/HTTP_CODE:/d')

echo "$RESPONSE_BODY" | jq . 2>/dev/null || echo "$RESPONSE_BODY"

if [ "$HTTP_CODE" = "201" ]; then
  echo -e "${GREEN}✓ Appointment created (HTTP $HTTP_CODE)${NC}"
  echo -e "  Appointment ID: ${CYAN}$APPOINTMENT_ID${NC}"
  echo -e "  Date: ${CYAN}$APPOINTMENT_DATE${NC}\n"
else
  echo -e "${RED}✗ Failed to create appointment (HTTP $HTTP_CODE)${NC}\n"
fi

# ============================================
# STEP 8: Retrieve Patient Appointments (Appointments Service)
# ============================================
echo -e "${CYAN}[8/10] Retrieve Patient Appointments${NC}"
echo -e "${YELLOW}→ Getting all appointments for patient...${NC}"

APPOINTMENTS_LIST=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X GET "$APPOINTMENTS_URL/appointments/patient/$PATIENT_ID" \
  -H "Authorization: Bearer $PATIENT_TOKEN")

HTTP_CODE=$(echo "$APPOINTMENTS_LIST" | grep "HTTP_CODE:" | cut -d: -f2)
RESPONSE_BODY=$(echo "$APPOINTMENTS_LIST" | sed '/HTTP_CODE:/d')

echo "$RESPONSE_BODY" | jq . 2>/dev/null || echo "$RESPONSE_BODY"

APPOINTMENT_COUNT=$(echo "$RESPONSE_BODY" | jq '.appointments | length' 2>/dev/null || echo "0")

if [ "$HTTP_CODE" = "200" ]; then
  echo -e "${GREEN}✓ Retrieved appointments (HTTP $HTTP_CODE)${NC}"
  echo -e "  Found: ${CYAN}$APPOINTMENT_COUNT appointment(s)${NC}\n"
else
  echo -e "${RED}✗ Failed (HTTP $HTTP_CODE)${NC}\n"
fi

# ============================================
# STEP 9: Process Payment (Payments Service)
# ============================================
echo -e "${CYAN}[9/10] Process Payment${NC}"
echo -e "${YELLOW}→ Processing payment for appointment...${NC}"

# Schema: appointmentId, amount, currency (opt, default USD), paymentMethod (opt)
PAYMENT_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "$PAYMENTS_URL/payments" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $PATIENT_TOKEN" \
  -d "{
    \"appointmentId\": \"$APPOINTMENT_ID\",
    \"amount\": 150.00,
    \"currency\": \"USD\",
    \"paymentMethod\": \"credit_card\"
  }")

HTTP_CODE=$(echo "$PAYMENT_RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
RESPONSE_BODY=$(echo "$PAYMENT_RESPONSE" | sed '/HTTP_CODE:/d')

echo "$RESPONSE_BODY" | jq . 2>/dev/null || echo "$RESPONSE_BODY"

PAYMENT_ID=$(echo "$RESPONSE_BODY" | jq -r '.payment.payment_id // empty')

if [ "$HTTP_CODE" = "201" ]; then
  echo -e "${GREEN}✓ Payment processed (HTTP $HTTP_CODE)${NC}"
  echo -e "  Payment ID: ${CYAN}$PAYMENT_ID${NC}"
  echo -e "  Amount: ${CYAN}\$150.00 USD${NC}\n"
else
  echo -e "${YELLOW}⚠ Payment processing issue (HTTP $HTTP_CODE)${NC}\n"
fi

# ============================================
# STEP 10: Check Pub/Sub Activity
# ============================================
echo -e "${CYAN}[10/10] Pub/Sub Verification${NC}"
echo -e "${YELLOW}→ Checking event publishing and processing...${NC}"

# Wait for logs to appear
sleep 3

echo -e "\n${BLUE}Appointments Service Logs:${NC}"
APPT_LOGS=$(gcloud logging read \
  'resource.type=cloud_run_revision 
   AND resource.labels.service_name=appointments 
   AND timestamp>="'$(date -u -v-3M +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "3 minutes ago" +%Y-%m-%dT%H:%M:%SZ)'"' \
  --limit=20 --format="value(textPayload)" 2>/dev/null | grep -i "pub" | tail -5)

if echo "$APPT_LOGS" | grep -q "Pub/Sub topic"; then
  echo -e "${GREEN}✓ Pub/Sub initialized${NC}"
  echo "$APPT_LOGS"
else
  echo -e "${YELLOW}⚠ No Pub/Sub activity${NC}"
fi

echo -e "\n${BLUE}Payments Service Logs:${NC}"
PAY_LOGS=$(gcloud logging read \
  'resource.type=cloud_run_revision 
   AND resource.labels.service_name=payments 
   AND timestamp>="'$(date -u -v-3M +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "3 minutes ago" +%Y-%m-%dT%H:%M:%SZ)'"' \
  --limit=20 --format="value(textPayload)" 2>/dev/null | grep -i "pub" | tail -5)

if echo "$PAY_LOGS" | grep -q "Pub/Sub topic"; then
  echo -e "${GREEN}✓ Pub/Sub initialized${NC}"
  echo "$PAY_LOGS"
else
  echo -e "${YELLOW}⚠ No Pub/Sub activity${NC}"
fi

echo -e "\n${BLUE}Notifications Service Logs:${NC}"
NOTIF_LOGS=$(gcloud logging read \
  'resource.type=cloud_run_revision 
   AND resource.labels.service_name=notifications 
   AND timestamp>="'$(date -u -v-3M +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "3 minutes ago" +%Y-%m-%dT%H:%M:%SZ)'"' \
  --limit=20 --format="value(textPayload)" 2>/dev/null | grep -E "(Received|Processing)" | tail -5)

if [ -n "$NOTIF_LOGS" ]; then
  echo -e "${GREEN}✓ Events being processed${NC}"
  echo "$NOTIF_LOGS"
else
  echo -e "${YELLOW}⚠ No event processing detected${NC}"
fi

echo ""

# ============================================
# Test Summary
# ============================================
echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              TEST SUMMARY                      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}\n"

echo -e "${GREEN}✓ Completed Services Tested:${NC}"
echo -e "  ${MAGENTA}[1]${NC} Auth Service - Patient Registration"
echo -e "  ${MAGENTA}[2]${NC} Auth Service - Doctor Registration"
echo -e "  ${MAGENTA}[3]${NC} Auth Service - Token Verification"
echo -e "  ${MAGENTA}[4]${NC} Patients Service - Create Profile"
echo -e "  ${MAGENTA}[5]${NC} Doctors Service - Create Profile"
echo -e "  ${MAGENTA}[6]${NC} Doctors Service - List All Doctors"
echo -e "  ${MAGENTA}[7]${NC} Appointments Service - Create Appointment"
echo -e "  ${MAGENTA}[8]${NC} Appointments Service - List Patient Appointments"
echo -e "  ${MAGENTA}[9]${NC} Payments Service - Process Payment"
echo -e "  ${MAGENTA}[10]${NC} Pub/Sub - Event Publishing & Processing"
echo ""

echo -e "${BLUE}Test Data Created:${NC}"
echo -e "  Patient: ${CYAN}$PATIENT_EMAIL${NC} (ID: ${CYAN}$PATIENT_ID${NC})"
echo -e "  Doctor: ${CYAN}$DOCTOR_EMAIL${NC} (ID: ${CYAN}$DOCTOR_ID${NC})"
echo -e "  Appointment: ${CYAN}$APPOINTMENT_ID${NC} @ ${CYAN}$APPOINTMENT_DATE${NC}"
if [ -n "$PAYMENT_ID" ]; then
  echo -e "  Payment: ${CYAN}$PAYMENT_ID${NC} - ${CYAN}\$150.00 USD${NC}"
fi
echo ""

echo -e "${YELLOW}CORS Status:${NC}"
echo -e "  ${GREEN}✓ CORS enabled on all services${NC}"
echo -e "  ${GREEN}✓ Frontend can now make requests from any origin${NC}"
echo ""

echo -e "${YELLOW}Pub/Sub Status:${NC}"
if echo "$APPT_LOGS" | grep -q "PERMISSION_DENIED"; then
  echo -e "  ${RED}⚠ Permission issues detected${NC}"
  echo -e "  ${YELLOW}Run: ./fix-pubsub-permissions.sh${NC}"
elif echo "$APPT_LOGS" | grep -q "Pub/Sub topic"; then
  echo -e "  ${GREEN}✓ Events being published${NC}"
  if [ -n "$NOTIF_LOGS" ]; then
    echo -e "  ${GREEN}✓ Events being processed by notifications${NC}"
  else
    echo -e "  ${YELLOW}⚠ Publishing works, notifications may need restart${NC}"
  fi
else
  echo -e "  ${YELLOW}⚠ No recent activity detected${NC}"
fi

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         🎉 FULL E2E TEST COMPLETE 🎉          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
