# Cloud-Native Medical App - Deployment Guide

## 🏗️ Infrastructure Overview

### Architecture
- **Cloud Provider**: Google Cloud Platform (GCP)
- **Compute**: Cloud Run (serverless containers)
- **Messaging**: Cloud Pub/Sub
- **Database**: Cloud SQL (PostgreSQL)
- **Container Registry**: Artifact Registry
- **IaC Tool**: Terraform

### Services Deployed
1. **Auth Service** - Authentication and authorization
2. **Patients Service** - Patient management
3. **Doctors Service** - Doctor management
4. **Appointments Service** - Appointment scheduling (publishes events)
5. **Payments Service** - Payment processing (publishes events)
6. **Notifications Service** - Event-driven notifications (subscribes to events)
7. **Reporting Service** - Analytics and reporting

---

## 📋 Prerequisites

Before deployment, ensure you have:

1. **Google Cloud SDK** installed
   ```bash
   gcloud --version
   ```

2. **Terraform** installed (v1.5+)
   ```bash
   terraform --version
   ```

3. **jq** installed (for postman script)
   ```bash
   brew install jq  # macOS
   ```

4. **GCP Project** created
   - Project ID: `proyecto-cloud-native`
   - Billing enabled
   - APIs enabled will be handled by Terraform

5. **Authentication** configured
   ```bash
   gcloud auth login
   gcloud auth application-default login
   ```

6. **Permissions** required:
   - `roles/owner` or the following:
     - `roles/run.admin`
     - `roles/iam.serviceAccountAdmin`
     - `roles/artifactregistry.admin`
     - `roles/cloudsql.admin`
     - `roles/pubsub.admin`
     - `roles/cloudbuild.builds.editor`

---

## 🚀 Deployment Steps

### Option 1: Automated Deployment (Recommended)

```bash
# Make scripts executable
chmod +x deploy.sh update-postman.sh

# Run full deployment (builds containers, deploys infrastructure)
./deploy.sh
```

This script will:
1. Set GCP project
2. Build all 7 service containers with Cloud Build
3. Push images to Artifact Registry
4. Deploy infrastructure with Terraform
5. Output service URLs

**Expected Duration**: 15-20 minutes

---

### Option 2: Manual Step-by-Step Deployment

#### Step 1: Build Container Images

```bash
export PROJECT_ID="proyecto-cloud-native"
export REGION="us-central1"
export REPO_NAME="medical-app"

# Build each service
gcloud builds submit \
  --tag ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/auth:latest \
  --timeout=10m \
  -f services/auth/Dockerfile \
  .

gcloud builds submit \
  --tag ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/appointments:latest \
  --timeout=10m \
  -f services/appointments/Dockerfile \
  .

gcloud builds submit \
  --tag ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/payments:latest \
  --timeout=10m \
  -f services/payments/Dockerfile \
  .

gcloud builds submit \
  --tag ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/notifications:latest \
  --timeout=10m \
  -f services/notifications/Dockerfile \
  .

gcloud builds submit \
  --tag ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/patients:latest \
  --timeout=10m \
  -f services/patients/Dockerfile \
  .

gcloud builds submit \
  --tag ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/doctors:latest \
  --timeout=10m \
  -f services/doctors/Dockerfile \
  .

gcloud builds submit \
  --tag ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/reporting:latest \
  --timeout=10m \
  -f services/reporting/Dockerfile \
  .
```

#### Step 2: Deploy Infrastructure

```bash
cd infra/terraform

# Initialize Terraform
terraform init

# Preview changes
terraform plan -var="project_id=${PROJECT_ID}" -var="region=${REGION}"

# Deploy
terraform apply -var="project_id=${PROJECT_ID}" -var="region=${REGION}"
```

#### Step 3: Get Service URLs

```bash
terraform output service_urls
terraform output deployment_summary
```

---

## 🧪 Testing with Postman

### Update Postman Collection with Live URLs

```bash
# After Terraform deployment completes
./update-postman.sh
```

This will automatically update `postman/Medical-App-E2E.postman_collection.json` with your deployed service URLs.

### Import Collection

1. Open Postman
2. Click **Import**
3. Select `postman/Medical-App-E2E.postman_collection.json`
4. Collection will be imported with all environment variables set

### Run E2E Test Flow

The collection includes:

1. **Health Checks** - Verify all services are running
2. **E2E Appointment Booking Flow**:
   - Create appointment (triggers Pub/Sub event)
   - Process payment (triggers Pub/Sub event)
   - Verify notifications (check Cloud Logging)
3. **Load Tests** - Multiple appointment creation

**Recommended Test Order**:
```
1. Run "1. Health Checks" folder (all requests)
2. Run "2. E2E Appointment Booking Flow" folder in sequence
3. Check Cloud Logging for notification events
```

---

## 📊 Monitoring & Verification

### View Pub/Sub Messages

```bash
# List topics
gcloud pubsub topics list

# View subscriptions
gcloud pubsub subscriptions list

# Pull messages (for testing)
gcloud pubsub subscriptions pull notifications-service --limit=10
```

### View Cloud Run Logs

```bash
# View appointments service logs
gcloud run services logs read appointments --region=us-central1

# View notifications service logs (to see event processing)
gcloud run services logs read notifications --region=us-central1
```

### Cloud Console Links

After deployment, access:

- **Cloud Run Services**: https://console.cloud.google.com/run?project=proyecto-cloud-native
- **Pub/Sub Topics**: https://console.cloud.google.com/cloudpubsub/topic/list?project=proyecto-cloud-native
- **Cloud SQL**: https://console.cloud.google.com/sql/instances?project=proyecto-cloud-native
- **Artifact Registry**: https://console.cloud.google.com/artifacts?project=proyecto-cloud-native
- **Cloud Logging**: https://console.cloud.google.com/logs?project=proyecto-cloud-native

---

## 🔍 Troubleshooting

### Container Build Fails

```bash
# Check Cloud Build logs
gcloud builds list --limit=5

# View specific build
gcloud builds log <BUILD_ID>
```

### Terraform Apply Fails

```bash
# Check state
terraform show

# Destroy and retry
terraform destroy -var="project_id=proyecto-cloud-native"
terraform apply -var="project_id=proyecto-cloud-native"
```

### Service Not Responding

```bash
# Check service status
gcloud run services describe <SERVICE_NAME> --region=us-central1

# View recent logs
gcloud run services logs read <SERVICE_NAME> --limit=50 --region=us-central1

# Check IAM permissions
gcloud run services get-iam-policy <SERVICE_NAME> --region=us-central1
```

### Pub/Sub Messages Not Arriving

```bash
# Verify topic exists
gcloud pubsub topics describe appointments

# Check subscription
gcloud pubsub subscriptions describe notifications-service

# Verify service account permissions
gcloud projects get-iam-policy proyecto-cloud-native \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:runtime-sa@*"
```

---

## 🧹 Cleanup

### Destroy All Resources

```bash
cd infra/terraform
terraform destroy -var="project_id=proyecto-cloud-native" -var="region=us-central1"
```

### Delete Container Images

```bash
gcloud artifacts docker images delete \
  us-central1-docker.pkg.dev/proyecto-cloud-native/medical-app/auth:latest \
  --quiet

# Repeat for all services...
```

---

## 📝 What's Not Included (Future Work)

This deployment focuses on **backend E2E testing**. The following are NOT included:

❌ **Frontend** - No web UI deployed  
❌ **API Gateway** - Services are publicly accessible (for testing)  
❌ **Database Schemas** - Cloud SQL instance exists but no tables created  
❌ **Authentication** - Auth service is a stub (no JWT validation)  
❌ **SSL Certificates** - Using Cloud Run default SSL  
❌ **Custom Domain** - Using default `.run.app` domains  
❌ **CI/CD Pipeline** - Manual deployment only  
❌ **Firestore** - Only Cloud SQL deployed  
❌ **Cloud Storage** - Not deployed  

### To Add Database Schema:

```bash
# Connect to Cloud SQL
gcloud sql connect healthcare-sql --user=postgres --quiet

# Create tables manually or use migration tool
```

---

## 🎯 Success Criteria

After deployment, you should be able to:

✅ Access all 7 service health endpoints  
✅ Create an appointment via POST /appointments  
✅ Process payment via POST /payments  
✅ See Pub/Sub messages in Cloud Console  
✅ See notification logs in Cloud Logging  
✅ Run Postman collection successfully  

---

## 📞 Support

For issues:
1. Check Cloud Logging first
2. Review Terraform state
3. Verify IAM permissions
4. Check container build logs

**Project Structure**:
```
.
├── deploy.sh                    # Automated deployment script
├── update-postman.sh            # Update Postman with URLs
├── infra/terraform/             # Infrastructure as Code
│   ├── main.tf                  # Main resources
│   ├── variables.tf             # Input variables
│   └── outputs.tf               # Output values
├── services/                    # Microservices
│   ├── auth/
│   ├── appointments/
│   ├── payments/
│   ├── notifications/
│   ├── patients/
│   ├── doctors/
│   └── reporting/
└── postman/                     # API testing
    └── Medical-App-E2E.postman_collection.json
```

---

## 🏆 Team

- Camilo Andres Pinzon Ruiz
- Miguel Angel Ortiz Escobar
- Omar Leonardo Zambrano Pulgarin
- Jesus Ernesto Quiñones Cely

**Project**: Cloud-Native Medical Appointment System  
**Course**: Diplomado Arquitectura - Módulo 1  
**Institution**: Universidad Nacional  
