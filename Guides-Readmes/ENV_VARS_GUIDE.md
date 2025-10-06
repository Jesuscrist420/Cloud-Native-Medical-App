# Environment Variables Setup & Deployment Guide

## 📋 Table of Contents
1. [Getting Cloud SQL Connection Name](#1-getting-cloud-sql-connection-name)
2. [Setting Environment Variables](#2-setting-environment-variables)
3. [Verifying Configuration](#3-verifying-configuration)
4. [Notifications Service Update](#4-notifications-service-update)
5. [Deployment Checklist](#5-deployment-checklist)

---

## 1. Getting Cloud SQL Connection Name

Your Cloud SQL Connection Name follows this format: `PROJECT_ID:REGION:INSTANCE_NAME`

### Find it using `gcloud`:
```bash
gcloud sql instances describe healthcare-sql \
  --project=proyecto-cloud-native \
  --format="value(connectionName)"
```

**Example output**: `proyecto-cloud-native:us-central1:healthcare-sql`

---

## 2. Setting Environment Variables

### Option A: Using the Script (Recommended) ⚡

I've created a script that will set all environment variables at once:

```bash
./set-env-vars.sh
```

**What it will ask you:**
1. **Cloud SQL Connection Name** - Get from step 1 above
2. **Database Password** - Your postgres password from Terraform
3. **JWT Secret** - Press Enter to auto-generate a secure random key

**What it does:**
- ✅ Sets all required env vars for all 7 services
- ✅ Configures Cloud SQL connections for appointments & payments
- ✅ Generates a secure JWT secret
- ✅ Sets up bucket names for patients, doctors, and reporting

---

### Option B: Manual Setup via `gcloud` CLI

If you prefer to set them manually:

#### **Appointments Service**
```bash
gcloud run services update appointments \
  --region=us-central1 \
  --set-env-vars="GOOGLE_CLOUD_PROJECT=proyecto-cloud-native,DB_HOST=/cloudsql/PROJECT:REGION:INSTANCE,DB_PORT=5432,DB_NAME=appointments_db,DB_USER=postgres,DB_PASSWORD=YOUR_PASSWORD,TOPIC_APPOINTMENTS=appointments" \
  --add-cloudsql-instances=PROJECT:REGION:INSTANCE
```

#### **Payments Service**
```bash
gcloud run services update payments \
  --region=us-central1 \
  --set-env-vars="GOOGLE_CLOUD_PROJECT=proyecto-cloud-native,DB_HOST=/cloudsql/PROJECT:REGION:INSTANCE,DB_PORT=5432,DB_NAME=payments_db,DB_USER=postgres,DB_PASSWORD=YOUR_PASSWORD,TOPIC_PAYMENTS=payments" \
  --add-cloudsql-instances=PROJECT:REGION:INSTANCE
```

#### **Auth Service**
```bash
gcloud run services update auth \
  --region=us-central1 \
  --set-env-vars="GOOGLE_CLOUD_PROJECT=proyecto-cloud-native,JWT_SECRET=YOUR_SECRET_KEY"
```

#### **Patients Service**
```bash
gcloud run services update patients \
  --region=us-central1 \
  --set-env-vars="GOOGLE_CLOUD_PROJECT=proyecto-cloud-native,PATIENTS_BUCKET=proyecto-cloud-native-patients-documents"
```

#### **Doctors Service**
```bash
gcloud run services update doctors \
  --region=us-central1 \
  --set-env-vars="GOOGLE_CLOUD_PROJECT=proyecto-cloud-native,DOCTORS_BUCKET=proyecto-cloud-native-doctors-documents"
```

#### **Reporting Service**
```bash
gcloud run services update reporting \
  --region=us-central1 \
  --set-env-vars="GOOGLE_CLOUD_PROJECT=proyecto-cloud-native,REPORTS_BUCKET=proyecto-cloud-native-reports"
```

#### **Notifications Service**
```bash
gcloud run services update notifications \
  --region=us-central1 \
  --set-env-vars="GOOGLE_CLOUD_PROJECT=proyecto-cloud-native,TOPIC_NOTIFICATIONS=notifications,SUB_NOTIFICATIONS=notifications-service"
```

---

### Option C: Using Cloud Console (GUI) 🖥️

1. Go to [Cloud Run Console](https://console.cloud.google.com/run?project=proyecto-cloud-native)
2. Click on a service (e.g., **appointments**)
3. Click **"EDIT & DEPLOY NEW REVISION"** button
4. Scroll to **"Variables & Secrets"** section
5. Click **"+ ADD VARIABLE"**
6. Add environment variables:
   - Key: `GOOGLE_CLOUD_PROJECT`
   - Value: `proyecto-cloud-native`
7. Repeat for all variables needed for that service
8. For **appointments** and **payments** services only:
   - Scroll to **"Connections"** section
   - Click **"+ ADD CONNECTION"**
   - Select **"Cloud SQL connections"**
   - Choose your **healthcare-sql** instance
9. Click **"DEPLOY"** at the bottom
10. Repeat for all 7 services

---

## 3. Verifying Configuration

After setting environment variables, verify they're set correctly:

```bash
# Check appointments service
gcloud run services describe appointments \
  --region=us-central1 \
  --format="value(spec.template.spec.containers[0].env)"

# Check auth service
gcloud run services describe auth \
  --region=us-central1 \
  --format="value(spec.template.spec.containers[0].env)"
```

---

## 4. Notifications Service Update ✅

### What Changed?

The notifications service now **actively pulls and processes messages** from Pub/Sub:

#### **New Features:**

✅ **Active Message Listening**
- Automatically receives messages from Pub/Sub subscriptions
- No manual polling required - uses event-driven listeners

✅ **Multiple Event Handlers**
- `notification.send` - Processes direct notification requests
- `appointment.created` - Listens for new appointments
- `appointment.cancelled` - Listens for cancelled appointments
- `payment.completed` - Listens for successful payments
- `payment.failed` - Listens for failed payments

✅ **Statistics Tracking**
- New `/stats` endpoint showing:
  - Total processed notifications
  - Failed notifications count
  - Breakdown by channel (email, SMS, push)

✅ **Better Logging**
- Emoji-based console output for easy debugging
- Event ID tracking
- Detailed error messages

✅ **Graceful Shutdown**
- Properly unsubscribes from Pub/Sub on SIGTERM
- Clean resource cleanup

✅ **Error Handling**
- Automatic message retry on failure (nack)
- Error logging with stack traces
- Continues running even if Pub/Sub fails to initialize

#### **Testing the Notifications Service:**

After deployment, you can:

1. **Check health**: `curl https://notifications-SERVICE_URL/healthz`
2. **View stats**: `curl https://notifications-SERVICE_URL/stats`
3. **Trigger a test notification**:
   ```bash
   curl -X POST https://appointments-SERVICE_URL/appointments \
     -H "Content-Type: application/json" \
     -d '{
       "appointmentId": "apt_test_001",
       "patientId": "pat_001",
       "doctorId": "doc_001",
       "datetime": "2025-10-15T14:00:00Z"
     }'
   ```
4. **Check logs**: `gcloud run services logs read notifications --region=us-central1`

You should see output like:
```
🔔 Actively listening for notification messages...
📅 Appointment created notification: apt_test_001
```

---

## 5. Deployment Checklist

### ✅ Pre-Deployment Steps

- [x] All TypeScript code compiles successfully (`pnpm build`)
- [x] Repository pattern implemented in all services
- [x] Notifications service updated with active message pulling
- [ ] Environment variables set (run `./set-env-vars.sh`)
- [ ] Save JWT secret securely

### 🚀 Deploy Updated Services

After setting environment variables, deploy the services:

```bash
./deploy.sh
```

This will:
1. Build new Docker images with database integration
2. Push to Artifact Registry
3. Deploy to Cloud Run with new environment variables

**Estimated time**: ~15-20 minutes

---

### 🧪 Post-Deployment Testing

#### 1. **Test Health Checks**
```bash
# Test all services
curl https://appointments-667268984833.us-central1.run.app/healthz
curl https://payments-667268984833.us-central1.run.app/healthz
curl https://auth-667268984833.us-central1.run.app/healthz
curl https://patients-667268984833.us-central1.run.app/healthz
curl https://doctors-667268984833.us-central1.run.app/healthz
curl https://reporting-667268984833.us-central1.run.app/healthz
curl https://notifications-667268984833.us-central1.run.app/healthz
```

#### 2. **Test Auth Flow**
```bash
# Register a user
curl -X POST https://auth-667268984833.us-central1.run.app/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "securePassword123",
    "role": "patient"
  }'

# Login
curl -X POST https://auth-667268984833.us-central1.run.app/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "securePassword123"
  }'
```

#### 3. **Test Appointments**
```bash
# Create appointment
curl -X POST https://appointments-667268984833.us-central1.run.app/appointments \
  -H "Content-Type: application/json" \
  -d '{
    "appointmentId": "apt_001",
    "patientId": "pat_001",
    "doctorId": "doc_001",
    "datetime": "2025-10-15T14:00:00Z",
    "notes": "Annual checkup"
  }'

# Get appointment
curl https://appointments-667268984833.us-central1.run.app/appointments/apt_001
```

#### 4. **Test Database Persistence**
```bash
# Create appointment
curl -X POST https://appointments-667268984833.us-central1.run.app/appointments -d '...'

# Retrieve it - should return the same data
curl https://appointments-667268984833.us-central1.run.app/appointments/apt_001
```

#### 5. **Test Notifications**
```bash
# Check stats
curl https://notifications-667268984833.us-central1.run.app/stats

# Create appointment (triggers notification)
curl -X POST https://appointments-667268984833.us-central1.run.app/appointments -d '...'

# Check logs to see notification processing
gcloud run services logs read notifications --region=us-central1 --limit=50
```

#### 6. **Verify Database Data**
```bash
# Connect to Cloud SQL
gcloud sql connect healthcare-sql --user=postgres

# Check appointments table
SELECT * FROM appointments;

# Check payments table
\c payments_db
SELECT * FROM payments;
```

---

## 🔍 Troubleshooting

### Environment Variables Not Taking Effect?
- Redeploy the service: `./deploy.sh`
- Or update with new revision: `gcloud run services update SERVICE_NAME ...`

### Cloud SQL Connection Issues?
- Verify connection name format: `PROJECT:REGION:INSTANCE`
- Check that Cloud SQL connection is added: `--add-cloudsql-instances=...`
- Ensure service account has Cloud SQL Client role

### Notifications Not Processing Messages?
- Check logs: `gcloud run services logs read notifications`
- Verify subscription exists: `gcloud pubsub subscriptions list`
- Check Pub/Sub permissions for service account

### JWT Token Issues?
- Ensure JWT_SECRET is set and consistent
- Check token expiration (default 24h)
- Verify /auth/verify endpoint works

---

## 📊 Environment Variables Summary

| Service | Variables | Cloud SQL | Storage Bucket |
|---------|-----------|-----------|----------------|
| **Appointments** | `GOOGLE_CLOUD_PROJECT`, `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `TOPIC_APPOINTMENTS` | ✅ Yes | ❌ No |
| **Payments** | `GOOGLE_CLOUD_PROJECT`, `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `TOPIC_PAYMENTS` | ✅ Yes | ❌ No |
| **Auth** | `GOOGLE_CLOUD_PROJECT`, `JWT_SECRET` | ❌ No | ❌ No |
| **Patients** | `GOOGLE_CLOUD_PROJECT`, `PATIENTS_BUCKET` | ❌ No | ✅ Yes |
| **Doctors** | `GOOGLE_CLOUD_PROJECT`, `DOCTORS_BUCKET` | ❌ No | ✅ Yes |
| **Reporting** | `GOOGLE_CLOUD_PROJECT`, `REPORTS_BUCKET` | ❌ No | ✅ Yes |
| **Notifications** | `GOOGLE_CLOUD_PROJECT`, `TOPIC_NOTIFICATIONS`, `SUB_NOTIFICATIONS` | ❌ No | ❌ No |

---

## 🎯 Quick Commands Reference

```bash
# Get Cloud SQL connection name
gcloud sql instances describe healthcare-sql --format="value(connectionName)"

# Set all env vars (interactive)
./set-env-vars.sh

# Deploy all services with new code
./deploy.sh

# Check service health
curl https://SERVICE_URL/healthz

# View logs
gcloud run services logs read SERVICE_NAME --region=us-central1 --limit=50

# Check environment variables
gcloud run services describe SERVICE_NAME --region=us-central1 --format="value(spec.template.spec.containers[0].env)"
```

---

**Ready to proceed? Run `./set-env-vars.sh` then `./deploy.sh`** 🚀
