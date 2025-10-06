# Infrastructure Architecture Summary

## 📊 Database Architecture by Service

| Service | Primary Database | Secondary Storage | Justification |
|---------|-----------------|-------------------|---------------|
| **Auth** | Firestore (Native Mode) | - | Document-based user profiles, sessions, and roles. NoSQL for flexible schema |
| **Appointments** | Cloud SQL (PostgreSQL) | - | Relational data with appointments, schedules, strong ACID guarantees |
| **Payments** | Cloud SQL (PostgreSQL) | - | Financial transactions require ACID compliance and strong consistency |
| **Notifications** | None (Stateless) | - | Event-driven service, processes messages from Pub/Sub without persistence |
| **Patients** | Firestore | Cloud Storage | Patient records in Firestore + medical documents (PDFs, images) in buckets |
| **Doctors** | Firestore | Cloud Storage | Doctor profiles in Firestore + credentials/certificates in buckets |
| **Reporting** | - | Cloud Storage | Generates and stores reports (CSV, PDF) directly to buckets |

## 🗄️ Detailed Database Configuration

### 1. Firestore (Native Mode)
- **Used by**: Auth, Patients, Doctors
- **Location**: `us-central1` (configurable)
- **Type**: NoSQL Document Database
- **Collections Structure**:
  ```
  auth/
    ├── users/
    ├── sessions/
    └── roles/
  
  patients/
    ├── profiles/
    ├── medical-history/
    └── appointments-history/
  
  doctors/
    ├── profiles/
    ├── specializations/
    └── availability-schedules/
  ```

### 2. Cloud SQL (PostgreSQL 15)
- **Used by**: Appointments, Payments
- **Instance Name**: `healthcare-sql`
- **Tier**: `db-f1-micro` (1 shared vCPU, 614 MB RAM)
- **Region**: `us-central1`
- **Databases**:
  - `appointments` - Appointment records
  - `payments` - Payment transactions
- **User**: `medical-app`
- **Backup**: Enabled (daily at 03:00 UTC)
- **Connection**: Public IP (authorized networks configured)

**Schema Recommendations** (not created by Terraform):
```sql
-- Appointments Database
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

-- Payments Database
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

### 3. Cloud Storage Buckets

| Bucket Name | Purpose | Versioning | Lifecycle Policy |
|-------------|---------|------------|------------------|
| `{project}-patients-documents` | Patient medical records, test results, images | Enabled | None (keep all) |
| `{project}-doctors-documents` | Doctor credentials, certificates, licenses | Enabled | None (keep all) |
| `{project}-reporting` | Generated reports (analytics, summaries) | Disabled | Delete after 365 days |
| `{project}-application-logs` | Application log exports | Disabled | Delete after 90 days |

**Storage Structure**:
```
patients-documents/
├── {patient_id}/
│   ├── medical-records/
│   │   ├── record-{date}.pdf
│   │   └── test-results-{date}.pdf
│   └── images/
│       └── scan-{date}.jpg

doctors-documents/
├── {doctor_id}/
│   ├── credentials/
│   │   └── license-{type}.pdf
│   └── certificates/
│       └── certification-{name}.pdf

reporting/
├── daily/
│   └── appointments-summary-{date}.csv
├── monthly/
│   └── revenue-report-{month}.pdf
└── analytics/
    └── patient-metrics-{date}.json
```

## 📊 Pub/Sub Event Architecture

### Topics
1. **appointments** - Published by: Appointments Service
   - Events: `appointment.created`, `appointment.cancelled`, `appointment.updated`
   
2. **payments** - Published by: Payments Service
   - Events: `payment.completed`, `payment.failed`, `payment.refunded`
   
3. **notifications** - Published by: Multiple services
   - Events: `notification.send`

### Subscriptions
- `notifications-service` → subscribes to `notifications` topic
- `notifications-from-appointments` → subscribes to `appointments` topic
- `notifications-from-payments` → subscribes to `payments` topic

### Event Flow
```
Appointments Service
    ↓ publishes event
appointments topic
    ↓ subscription
notifications-from-appointments
    ↓ pulls messages
Notifications Service → sends email/SMS
```

## 🔍 Observability Stack

### 1. Cloud Logging
- **Log Sink**: `medical-app-logs`
- **Destination**: Cloud Storage bucket (`{project}-application-logs`)
- **Filter**: All Cloud Run services (auth, appointments, payments, etc.)
- **Retention**: 90 days
- **Access**: https://console.cloud.google.com/logs

### 2. Cloud Monitoring
- **Dashboard**: `Medical App - Service Health`
- **Widgets**:
  - Request Count by Service (real-time)
  - Error Rate by Service (5xx errors)
  - Request Latency P95
  - Container Instance Count

### 3. Cloud Trace
- **Enabled**: Yes (automatic for Cloud Run)
- **Sampling**: Default (1 in 10,000 requests)
- **Trace Context**: Propagated via HTTP headers

### 4. Alert Policies
- **High Error Rate Alert**
  - Condition: 5xx errors > 5% for 60 seconds
  - Notification: Email (configure in GCP Console)
  - Auto-close: After 30 minutes

### Log Queries (Saved in Console)

**View all service logs**:
```
resource.type="cloud_run_revision"
resource.labels.service_name=~"(auth|appointments|payments|notifications|patients|doctors|reporting)"
```

**View errors only**:
```
resource.type="cloud_run_revision"
severity>=ERROR
```

**View Pub/Sub publish events**:
```
resource.type="cloud_run_revision"
jsonPayload.message=~"publishing.*event"
```

## 🔐 IAM & Service Accounts

### Runtime Service Account
- **Name**: `runtime-sa@{project}.iam.gserviceaccount.com`
- **Roles**:
  - `roles/pubsub.publisher` - Publish Pub/Sub messages
  - `roles/pubsub.subscriber` - Subscribe to Pub/Sub messages
  - `roles/cloudsql.client` - Connect to Cloud SQL
  - `roles/datastore.user` - Read/write Firestore
  - `roles/storage.objectAdmin` - Read/write Cloud Storage
  - `roles/logging.logWriter` - Write logs
  - `roles/monitoring.metricWriter` - Write metrics
  - `roles/cloudtrace.agent` - Write traces

## 📈 Monitoring Metrics to Watch

### Service Health
- **Request Count**: `run.googleapis.com/request_count`
- **Error Rate**: `run.googleapis.com/request_count` (filtered by response_code_class="5xx")
- **Latency**: `run.googleapis.com/request_latencies` (P50, P95, P99)
- **Instance Count**: `run.googleapis.com/container/instance_count`

### Database
- **Cloud SQL Connections**: `cloudsql.googleapis.com/database/network/connections`
- **Cloud SQL CPU**: `cloudsql.googleapis.com/database/cpu/utilization`
- **Firestore Reads**: `firestore.googleapis.com/document/read_count`
- **Firestore Writes**: `firestore.googleapis.com/document/write_count`

### Pub/Sub
- **Message Publish Count**: `pubsub.googleapis.com/topic/send_message_operation_count`
- **Subscription Undelivered Messages**: `pubsub.googleapis.com/subscription/num_undelivered_messages`
- **Subscription Oldest Unacked Message Age**: `pubsub.googleapis.com/subscription/oldest_unacked_message_age`

### Storage
- **Bucket Total Bytes**: `storage.googleapis.com/storage/total_bytes`
- **Bucket Object Count**: `storage.googleapis.com/storage/object_count`

## 🚀 Scaling Configuration

### Cloud Run Auto-scaling
- **Default**: 0-100 instances per service
- **Notifications Service**: Min 1 instance (always running for Pub/Sub)
- **Scale Up**: On incoming requests
- **Scale Down**: After 15 minutes of no traffic
- **Concurrency**: 80 requests per container (default)

### Database Scaling
- **Cloud SQL**: Manual vertical scaling (upgrade tier as needed)
- **Firestore**: Automatic, unlimited horizontal scaling
- **Cloud Storage**: Automatic, unlimited capacity

## 💰 Cost Optimization Notes

### Current Configuration (Development/Testing)
- **Cloud SQL**: `db-f1-micro` (~$7/month if running 24/7)
- **Cloud Run**: Pay per request (free tier: 2M requests/month)
- **Firestore**: Free tier: 1GB storage, 50K reads, 20K writes per day
- **Cloud Storage**: $0.020 per GB/month (Standard class)
- **Pub/Sub**: Free tier: 10GB/month

### Production Recommendations
1. Upgrade Cloud SQL to `db-custom-2-7680` (2 vCPU, 7.5 GB RAM)
2. Enable Cloud SQL replica for read scaling
3. Enable Cloud CDN for Cloud Storage buckets
4. Configure budget alerts in GCP Console
5. Use committed use discounts for predictable workloads

## 🔧 Post-Deployment Tasks

### Manual Setup Required
1. **Create Cloud SQL schemas** (use SQL scripts above)
2. **Initialize Firestore collections** (create index if needed)
3. **Configure email/SMS provider** in Notifications service
4. **Set up custom domain** (optional)
5. **Configure Cloud Armor** for DDoS protection (production)
6. **Enable Secret Manager** for sensitive credentials (recommended)
7. **Set up CI/CD pipeline** (GitHub Actions, Cloud Build)

### Testing Checklist
- [ ] All health endpoints return 200 OK
- [ ] Create appointment → event published to Pub/Sub
- [ ] Process payment → event published to Pub/Sub
- [ ] Notification service logs show event processing
- [ ] Cloud SQL connection successful
- [ ] Firestore read/write operations working
- [ ] Cloud Storage upload/download working
- [ ] Monitoring dashboard shows metrics
- [ ] Logs appear in Cloud Logging
- [ ] Alert policy doesn't trigger (no errors)

## 📚 Additional Resources

- **Terraform State**: Stored locally in `infra/terraform/terraform.tfstate`
- **Environment Variables**: Automatically injected by Terraform into Cloud Run
- **Postman Collection**: `postman/Medical-App-E2E.postman_collection.json`
- **Deployment Script**: `deploy.sh` (automated deployment)
- **Health Check Script**: `health-check.sh` (verify all services)
- **Update Postman Script**: `update-postman.sh` (sync URLs after deployment)

## 🎯 Architecture Decisions

### Why Firestore for Auth, Patients, Doctors?
- Flexible schema for user profiles and medical records
- Built-in real-time synchronization (future mobile app)
- Automatic scaling without capacity planning
- Strong consistency within document
- Native GCP integration with Cloud Run

### Why Cloud SQL for Appointments, Payments?
- Financial transactions require ACID guarantees
- Complex queries with JOINs (appointments + patient + doctor)
- Strong consistency across transactions
- Mature ecosystem (ORM support, backup tools)
- Regulatory compliance for financial data

### Why Cloud Storage for Documents?
- Cost-effective for large binary files (images, PDFs)
- Built-in versioning for audit trail
- Lifecycle management for old reports
- Signed URLs for secure temporary access
- Integration with Cloud Functions for processing

### Why No Database for Notifications?
- Stateless event-driven architecture
- Idempotent message processing
- No need to persist notification history (logged in Cloud Logging)
- Reduces operational complexity
- Can integrate with external services (SendGrid, Twilio)

---

**Last Updated**: October 4, 2025  
**Terraform Version**: 1.5+  
**GCP Provider Version**: 5.34+
