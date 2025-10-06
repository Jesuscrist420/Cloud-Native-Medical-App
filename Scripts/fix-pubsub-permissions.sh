#!/bin/bash

# Fix Pub/Sub Permissions for Cloud Run Services
# This script grants the necessary IAM permissions for services to publish/subscribe to Pub/Sub

set -e

PROJECT_ID="proyecto-cloud-native"
REGION="us-central1"

echo "🔧 Fixing Pub/Sub Permissions for Cloud Run Services"
echo "=================================================="
echo ""

# Get the default compute service account
SERVICE_ACCOUNT=$(gcloud iam service-accounts list --filter="email:${PROJECT_ID}@appspot.gserviceaccount.com" --format="value(email)")

if [ -z "$SERVICE_ACCOUNT" ]; then
  SERVICE_ACCOUNT="${PROJECT_ID}@appspot.gserviceaccount.com"
fi

echo "Service Account: $SERVICE_ACCOUNT"
echo ""

# Grant Pub/Sub Publisher role (for appointments, payments services)
echo "✓ Granting Pub/Sub Publisher role..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT" \
  --role="roles/pubsub.publisher" \
  --condition=None \
  2>&1 | grep -E "(Updated|already has)" || true

# Grant Pub/Sub Subscriber role (for notifications service)
echo "✓ Granting Pub/Sub Subscriber role..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT" \
  --role="roles/pubsub.subscriber" \
  --condition=None \
  2>&1 | grep -E "(Updated|already has)" || true

# Grant Pub/Sub Viewer role (to list topics/subscriptions)
echo "✓ Granting Pub/Sub Viewer role..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT" \
  --role="roles/pubsub.viewer" \
  --condition=None \
  2>&1 | grep -E "(Updated|already has)" || true

echo ""
echo "=================================================="
echo "✅ Permissions granted successfully!"
echo ""
echo "Next steps:"
echo "1. Wait 60 seconds for permissions to propagate"
echo "2. Restart services to pick up new permissions:"
echo ""
echo "   gcloud run services update appointments --region=$REGION --update-env-vars=REFRESH=\$(date +%s)"
echo "   gcloud run services update payments --region=$REGION --update-env-vars=REFRESH=\$(date +%s)"
echo "   gcloud run services update notifications --region=$REGION --update-env-vars=REFRESH=\$(date +%s)"
echo ""
echo "3. Test again by creating an appointment"
echo "4. Check notifications service logs to verify event processing"
