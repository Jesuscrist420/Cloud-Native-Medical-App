#!/bin/bash
# Quick health check script for all deployed services

set -e

echo "🏥 Cloud-Native Medical App - Health Check"
echo "=========================================="
echo ""

cd infra/terraform

# Get URLs from terraform output
SERVICES=$(terraform output -json service_urls)

if [ -z "$SERVICES" ]; then
  echo "❌ Error: No service URLs found. Have you deployed with terraform apply?"
  exit 1
fi

# Extract each URL
AUTH_URL=$(echo $SERVICES | jq -r '.auth')
PATIENTS_URL=$(echo $SERVICES | jq -r '.patients')
DOCTORS_URL=$(echo $SERVICES | jq -r '.doctors')
APPOINTMENTS_URL=$(echo $SERVICES | jq -r '.appointments')
PAYMENTS_URL=$(echo $SERVICES | jq -r '.payments')
NOTIFICATIONS_URL=$(echo $SERVICES | jq -r '.notifications')
REPORTING_URL=$(echo $SERVICES | jq -r '.reporting')

cd ../..

# Function to check health
check_health() {
  local name=$1
  local url=$2
  
  echo -n "Checking $name... "
  
  status_code=$(curl -s -o /dev/null -w "%{http_code}" "$url/healthz" || echo "000")
  
  if [ "$status_code" = "200" ]; then
    echo "✅ Healthy (200 OK)"
  else
    echo "❌ Unhealthy (HTTP $status_code)"
  fi
}

# Check all services
check_health "Auth        " "$AUTH_URL"
check_health "Patients    " "$PATIENTS_URL"
check_health "Doctors     " "$DOCTORS_URL"
check_health "Appointments" "$APPOINTMENTS_URL"
check_health "Payments    " "$PAYMENTS_URL"
check_health "Notifications" "$NOTIFICATIONS_URL"
check_health "Reporting   " "$REPORTING_URL"

echo ""
echo "=========================================="
echo "Health check complete!"
echo ""
echo "📝 To test E2E flow:"
echo "   1. Import postman/Medical-App-E2E.postman_collection.json"
echo "   2. Run '2. E2E Appointment Booking Flow'"
echo ""
