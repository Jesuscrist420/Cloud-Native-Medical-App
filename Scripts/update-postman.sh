#!/bin/bash
set -e

# This script extracts service URLs from Terraform and updates the Postman collection

echo "🔄 Updating Postman collection with deployed service URLs..."

cd infra/terraform

# Get service URLs from terraform output
AUTH_URL=$(terraform output -json service_urls | jq -r '.auth')
PATIENTS_URL=$(terraform output -json service_urls | jq -r '.patients')
DOCTORS_URL=$(terraform output -json service_urls | jq -r '.doctors')
APPOINTMENTS_URL=$(terraform output -json service_urls | jq -r '.appointments')
PAYMENTS_URL=$(terraform output -json service_urls | jq -r '.payments')
NOTIFICATIONS_URL=$(terraform output -json service_urls | jq -r '.notifications')
REPORTING_URL=$(terraform output -json service_urls | jq -r '.reporting')

cd ../..

# Update Postman collection using jq
COLLECTION_FILE="postman/Medical-App-E2E.postman_collection.json"

jq --arg auth "$AUTH_URL" \
   --arg patients "$PATIENTS_URL" \
   --arg doctors "$DOCTORS_URL" \
   --arg appointments "$APPOINTMENTS_URL" \
   --arg payments "$PAYMENTS_URL" \
   --arg notifications "$NOTIFICATIONS_URL" \
   --arg reporting "$REPORTING_URL" \
   '.variable[0].value = $auth |
    .variable[1].value = $patients |
    .variable[2].value = $doctors |
    .variable[3].value = $appointments |
    .variable[4].value = $payments |
    .variable[5].value = $notifications |
    .variable[6].value = $reporting' \
   "$COLLECTION_FILE" > "${COLLECTION_FILE}.tmp"

mv "${COLLECTION_FILE}.tmp" "$COLLECTION_FILE"

echo "✅ Postman collection updated!"
echo ""
echo "📋 Service URLs:"
echo "   Auth:          $AUTH_URL"
echo "   Patients:      $PATIENTS_URL"
echo "   Doctors:       $DOCTORS_URL"
echo "   Appointments:  $APPOINTMENTS_URL"
echo "   Payments:      $PAYMENTS_URL"
echo "   Notifications: $NOTIFICATIONS_URL"
echo "   Reporting:     $REPORTING_URL"
echo ""
echo "🧪 Import the collection in Postman:"
echo "   File: $COLLECTION_FILE"
