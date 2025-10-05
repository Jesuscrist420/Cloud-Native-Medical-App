# 🏥 Cloud-Native Medical App - Complete Deployment Guide

## 📋 Pre-Deployment Checklist

Before running any deployment commands, complete these steps:

### ✅ Step 1: Run Pre-Deployment Validation
```bash
./pre-deploy-check.sh
```

This script will verify:
- ✓ Required tools (gcloud, terraform, jq)
- ✓ GCP authentication
- ✓ Project configuration
- ✓ File structure
- ✓ Terraform syntax

**All checks must pass before proceeding!**

---

## 🗄️ Database Architecture Overview

| Service | Database Type | Details |
|---------|--------------|---------|
| **Auth** | Firestore | User profiles, sessions, roles |
| **Appointments** | Cloud SQL (PostgreSQL) | Appointment records with ACID guarantees |
| **Payments** | Cloud SQL (PostgreSQL) | Financial transactions |
| **Notifications** | None (Stateless) | Event-driven from Pub/Sub |
| **Patients** | Firestore + Cloud Storage | Records in Firestore, documents in buckets |
| **Doctors** | Firestore + Cloud Storage | Profiles in Firestore, credentials in buckets |
| **Reporting** | Cloud Storage | Generated reports stored in buckets |

📖 **Full details**: See [INFRASTRUCTURE.md](INFRASTRUCTURE.md)

---

## 🚀 Deployment Process

### Option 1: Automated Deployment (Recommended)

```bash
# 1. Validate prerequisites
./pre-deploy-check.sh

# 2. Deploy everything (builds containers + infrastructure)
./deploy.sh

# 3. Wait 15-25 minutes for completion

# 4. Update Postman collection with URLs
./update-postman.sh

# 5. Verify all services are healthy
./health-check.sh
```

### Option 2: Manual Step-by-Step

See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed manual deployment steps.

---

## 📊 What Gets Deployed

### Infrastructure
- ✅ 7 Cloud Run services (auth, appointments, payments, notifications, patients, doctors, reporting)
- ✅ Cloud SQL PostgreSQL instance with 2 databases (appointments, payments)
- ✅ Firestore Native Mode database (for auth, patients, doctors)
- ✅ 4 Cloud Storage buckets (patients, doctors, reporting, logs)
- ✅ 3 Pub/Sub topics + subscriptions
- ✅ Artifact Registry repository
- ✅ Monitoring dashboard + alert policy
- ✅ Log sink for centralized logging

### Observability Stack
- ✅ Cloud Logging (90-day retention)
- ✅ Cloud Monitoring dashboard
- ✅ Cloud Trace (automatic)
- ✅ Alert policy (high error rate)
- ✅ Custom metrics per service

---

## 🧪 Testing with Postman

### 1. Import Collection
```bash
# After deployment, update URLs
./update-postman.sh

# Import in Postman
File → Import → postman/Medical-App-E2E.postman_collection.json
```

### 2. Run Tests in Order

**Folder 1: Health Checks**
- Verifies all 7 services are responding

**Folder 2: E2E Appointment Booking Flow**
1. Create Appointment → Triggers Pub/Sub event
2. Process Payment → Triggers Pub/Sub event
3. Notifications → Check Cloud Logging for processed events

**Folder 3: Additional Tests**
- Load testing with multiple appointments

### 3. View Pub/Sub Events
```bash
# View notifications service logs
gcloud run services logs read notifications --region=us-central1 --limit=50

# Or use Cloud Console
https://console.cloud.google.com/logs?project=proyecto-cloud-native
```

---

## 📈 Monitoring & Observability

### Access Monitoring Dashboard
```bash
cd infra/terraform
terraform output observability_links
```

Or visit directly:
- **Dashboard**: https://console.cloud.google.com/monitoring
- **Logs**: https://console.cloud.google.com/logs
- **Trace**: https://console.cloud.google.com/traces

### Key Metrics to Watch
- Request count by service
- Error rate (5xx responses)
- Request latency (P95)
- Container instance count
- Pub/Sub undelivered messages

### Useful Log Queries

**All service logs**:
```
resource.type="cloud_run_revision"
resource.labels.service_name=~"(auth|appointments|payments|notifications|patients|doctors|reporting)"
```

**Errors only**:
```
resource.type="cloud_run_revision"
severity>=ERROR
```

**Pub/Sub events**:
```
resource.type="cloud_run_revision"
jsonPayload.message=~"publishing.*event"
```

---

## 🗄️ Post-Deployment: Database Setup

### Cloud SQL Schema Creation

```bash
# Get Cloud SQL IP
cd infra/terraform
terraform output cloud_sql_ip

# Connect (password: medical-app-2025)
gcloud sql connect healthcare-sql --user=medical-app --quiet
```

Then run:
```sql
-- Connect to appointments database
\c appointments

CREATE TABLE appointments (
    id SERIAL PRIMARY KEY,
    appointment_id VARCHAR(255) UNIQUE NOT NULL,
    patient_id VARCHAR(255) NOT NULL,
    doctor_id VARCHAR(255) NOT NULL,
    appointment_date TIMESTAMP NOT NULL,
    status VARCHAR(50) DEFAULT 'pending',
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Connect to payments database
\c payments

CREATE TABLE payments (
    id SERIAL PRIMARY KEY,
    payment_id VARCHAR(255) UNIQUE NOT NULL,
    appointment_id VARCHAR(255) NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    status VARCHAR(50) DEFAULT 'pending',
    payment_method VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Firestore Indexes (Optional)

Firestore will create indexes automatically, but you can create composite indexes via:
```bash
gcloud firestore indexes composite create \
  --collection-group=appointments \
  --field-config field-path=patientId,order=ASCENDING \
  --field-config field-path=appointment_date,order=DESCENDING
```

---

## 🔍 Troubleshooting

### Service Not Responding

```bash
# Check service status
gcloud run services describe <SERVICE_NAME> --region=us-central1

# View logs
gcloud run services logs read <SERVICE_NAME> --limit=100 --region=us-central1

# Check if service is deployed
gcloud run services list --region=us-central1
```

### Container Build Failed

```bash
# List recent builds
gcloud builds list --limit=5

# View build logs
gcloud builds log <BUILD_ID>
```

### Terraform Errors

```bash
cd infra/terraform

# Check state
terraform show

# Re-initialize if needed
rm -rf .terraform
terraform init

# Destroy and retry
terraform destroy -var="project_id=proyecto-cloud-native"
terraform apply -var="project_id=proyecto-cloud-native"
```

### Pub/Sub Messages Not Processing

```bash
# Check subscription backlog
gcloud pubsub subscriptions describe notifications-service

# Pull messages manually (for debugging)
gcloud pubsub subscriptions pull notifications-service --limit=10 --auto-ack

# View notifications service logs
gcloud run services logs read notifications --region=us-central1 --limit=100
```

---

## 🧹 Cleanup & Cost Management

### Destroy All Resources

```bash
cd infra/terraform
terraform destroy -var="project_id=proyecto-cloud-native" -var="region=us-central1"
```

### Stop Services Without Destroying

```bash
# Scale down to 0 instances (Cloud Run only charges when running)
gcloud run services update <SERVICE_NAME> --region=us-central1 --min-instances=0

# Stop Cloud SQL instance
gcloud sql instances patch healthcare-sql --activation-policy=NEVER
```

### Monitor Costs

```bash
# View current month costs
gcloud billing accounts list
gcloud billing projects describe proyecto-cloud-native
```

Or visit: https://console.cloud.google.com/billing

---

## 📊 Success Criteria

After deployment, you should have:

✅ All 7 services deployed to Cloud Run  
✅ Health endpoints returning 200 OK  
✅ Cloud SQL instance with 2 databases  
✅ Firestore database created  
✅ 4 Cloud Storage buckets created  
✅ 3 Pub/Sub topics + subscriptions  
✅ Monitoring dashboard visible  
✅ Log sink capturing service logs  
✅ Postman collection updated with URLs  
✅ E2E appointment flow working  
✅ Notifications processing Pub/Sub events  

---

## 📚 Documentation Files

- **[INFRASTRUCTURE.md](INFRASTRUCTURE.md)** - Complete database & observability architecture
- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Detailed manual deployment guide
- **[README.monorepo.md](README.monorepo.md)** - Monorepo structure (if exists)

---

## 🎯 Quick Command Reference

```bash
# Pre-deployment validation
./pre-deploy-check.sh

# Deploy everything
./deploy.sh

# Update Postman with service URLs
./update-postman.sh

# Health check all services
./health-check.sh

# View service logs
gcloud run services logs read <SERVICE> --region=us-central1 --limit=50

# Get service URLs
cd infra/terraform && terraform output service_urls

# Get database info
cd infra/terraform && terraform output database_summary

# Get monitoring links
cd infra/terraform && terraform output observability_links

# Destroy everything
cd infra/terraform && terraform destroy -var="project_id=proyecto-cloud-native"
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
**Date**: October 2025  

---

## 🚦 Getting Started NOW

```bash
# 1. Validate everything is ready
./pre-deploy-check.sh

# 2. If all checks pass, deploy!
./deploy.sh

# 3. Wait for completion, then test
./update-postman.sh
./health-check.sh

# 4. Import Postman collection and run E2E tests
```

**Estimated time**: 15-25 minutes  
**Estimated cost**: ~$15-20/month (development usage)

---

## 📞 Support & Issues

If you encounter issues:

1. **Check logs first**: `gcloud run services logs read <service>`
2. **Review Terraform state**: `cd infra/terraform && terraform show`
3. **Verify IAM permissions**: Ensure service account has required roles
4. **Check GCP Console**: https://console.cloud.google.com
5. **Review INFRASTRUCTURE.md**: Complete architecture documentation

**Common Issues**:
- Build timeout → Increase timeout in `deploy.sh`
- DB connection failed → Check Cloud SQL IP whitelist
- Pub/Sub not working → Verify service account IAM roles
- Firestore errors → Ensure API is enabled

---

**Ready to deploy? Run `./pre-deploy-check.sh` to get started! 🚀**
