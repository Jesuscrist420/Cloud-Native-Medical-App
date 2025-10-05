# 🎯 Deployment Architecture - Visual Summary

```
┌─────────────────────────────────────────────────────────────────────────┐
│                   CLOUD-NATIVE MEDICAL APP ARCHITECTURE                 │
│                         Google Cloud Platform                           │
└─────────────────────────────────────────────────────────────────────────┘

╔═══════════════════════════════════════════════════════════════════════╗
║                          CLOUD RUN SERVICES                           ║
╚═══════════════════════════════════════════════════════════════════════╝

┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│     Auth     │  │   Patients   │  │   Doctors    │  │  Reporting   │
│   Service    │  │   Service    │  │   Service    │  │   Service    │
└──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘
       │                 │                 │                 │
       ▼                 ▼                 ▼                 ▼
  [Firestore]     [Firestore +       [Firestore +      [Cloud
                   Cloud Storage]     Cloud Storage]     Storage]

┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ Appointments │  │   Payments   │  │ Notifications│
│   Service    │  │   Service    │  │   Service    │
└──────┬───────┘  └──────┬───────┘  └──────┬───────┘
       │                 │                 │
       ▼                 ▼                 │
   [Cloud SQL]      [Cloud SQL]            │
   PostgreSQL       PostgreSQL             │
                                           │
       │                 │                 │
       └────────┬────────┘                 │
                ▼                          ▼
          [PUB/SUB TOPICS]         [PUB/SUB
           appointments            SUBSCRIPTIONS]
           payments                notifications-service
           notifications           notifications-from-*

╔═══════════════════════════════════════════════════════════════════════╗
║                         DATABASE LAYER                                ║
╚═══════════════════════════════════════════════════════════════════════╝

┌─────────────────────────┐  ┌─────────────────────────┐
│    CLOUD SQL (PostgreSQL)│  │  FIRESTORE (Native)     │
│  ┌───────────────────┐   │  │  ┌───────────────────┐  │
│  │ appointments DB   │   │  │  │ auth collection   │  │
│  │ - appointments    │   │  │  │ - users          │  │
│  │ - schedules       │   │  │  │ - sessions       │  │
│  └───────────────────┘   │  │  └───────────────────┘  │
│  ┌───────────────────┐   │  │  ┌───────────────────┐  │
│  │ payments DB       │   │  │  │ patients coll.   │  │
│  │ - payments        │   │  │  │ - profiles       │  │
│  │ - transactions    │   │  │  │ - history        │  │
│  └───────────────────┘   │  │  └───────────────────┘  │
│                          │  │  ┌───────────────────┐  │
│  Connection:             │  │  │ doctors coll.    │  │
│  - Public IP            │  │  │ - profiles       │  │
│  - User: medical-app    │  │  │ - availability   │  │
│  - Pass: medical-app-2025│  │  └───────────────────┘  │
└─────────────────────────┘  └─────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                    CLOUD STORAGE BUCKETS                            │
│  ┌──────────────────────┐  ┌──────────────────────┐                │
│  │ patients-documents   │  │ doctors-documents    │                │
│  │ - Medical records    │  │ - Credentials        │                │
│  │ - Test results       │  │ - Certificates       │                │
│  │ - Images/Scans       │  │ - Licenses           │                │
│  │ Versioning: ON       │  │ Versioning: ON       │                │
│  └──────────────────────┘  └──────────────────────┘                │
│  ┌──────────────────────┐  ┌──────────────────────┐                │
│  │ reporting            │  │ application-logs     │                │
│  │ - Daily reports      │  │ - Service logs       │                │
│  │ - Monthly summaries  │  │ - Audit logs         │                │
│  │ Delete: 365 days     │  │ Delete: 90 days      │                │
│  └──────────────────────┘  └──────────────────────┘                │
└─────────────────────────────────────────────────────────────────────┘

╔═══════════════════════════════════════════════════════════════════════╗
║                       OBSERVABILITY STACK                             ║
╚═══════════════════════════════════════════════════════════════════════╝

┌─────────────────────────────────────────────────────────────────────┐
│                        CLOUD MONITORING                             │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Medical App Dashboard                                       │  │
│  │  ┌────────────────┐  ┌────────────────┐                     │  │
│  │  │ Request Count  │  │  Error Rate    │                     │  │
│  │  │  by Service    │  │  by Service    │                     │  │
│  │  └────────────────┘  └────────────────┘                     │  │
│  │  ┌────────────────┐  ┌────────────────┐                     │  │
│  │  │ Latency (P95)  │  │ Instance Count │                     │  │
│  │  │  by Service    │  │  by Service    │                     │  │
│  │  └────────────────┘  └────────────────┘                     │  │
│  └──────────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Alert Policies                                              │  │
│  │  • High Error Rate (>5% 5xx errors for 60s)                │  │
│  │  • Auto-close after 30 minutes                             │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                        CLOUD LOGGING                                │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Log Sink: medical-app-logs                                  │  │
│  │  • Filter: All Cloud Run services                          │  │
│  │  • Destination: Cloud Storage                              │  │
│  │  • Retention: 90 days                                      │  │
│  └──────────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Pre-configured Queries                                      │  │
│  │  • All service logs                                         │  │
│  │  • Errors only (severity >= ERROR)                         │  │
│  │  • Pub/Sub events                                          │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                        CLOUD TRACE                                  │
│  • Automatic tracing for all Cloud Run services                   │
│  • Trace context propagation via HTTP headers                     │
│  • Latency breakdown by service                                   │
└─────────────────────────────────────────────────────────────────────┘

╔═══════════════════════════════════════════════════════════════════════╗
║                          EVENT FLOW (E2E)                             ║
╚═══════════════════════════════════════════════════════════════════════╝

1. CREATE APPOINTMENT
   ┌──────────────────────────────────────────────────────────────┐
   │ POST /appointments                                           │
   │ { appointmentId, patientId, doctorId, datetime }            │
   └───────────────────────────┬──────────────────────────────────┘
                               ▼
   ┌───────────────────────────────────────────────────────────────┐
   │ Appointments Service                                          │
   │ 1. Save to Cloud SQL (appointments DB)                       │
   │ 2. Publish event to "appointments" topic                     │
   └───────────────────────────┬───────────────────────────────────┘
                               ▼
   ┌───────────────────────────────────────────────────────────────┐
   │ Pub/Sub: appointments topic                                   │
   │ Event: "appointment.created"                                 │
   └───────────────────────────┬───────────────────────────────────┘
                               ▼
   ┌───────────────────────────────────────────────────────────────┐
   │ Subscription: notifications-from-appointments                │
   └───────────────────────────┬───────────────────────────────────┘
                               ▼
   ┌───────────────────────────────────────────────────────────────┐
   │ Notifications Service                                         │
   │ Process: Send appointment confirmation email                 │
   │ Log: "sending email to patient@example.com"                  │
   └───────────────────────────────────────────────────────────────┘

2. PROCESS PAYMENT
   ┌──────────────────────────────────────────────────────────────┐
   │ POST /payments                                               │
   │ { appointmentId, amount, currency }                          │
   └───────────────────────────┬──────────────────────────────────┘
                               ▼
   ┌───────────────────────────────────────────────────────────────┐
   │ Payments Service                                              │
   │ 1. Save to Cloud SQL (payments DB)                           │
   │ 2. Publish event to "payments" topic                         │
   └───────────────────────────┬───────────────────────────────────┘
                               ▼
   ┌───────────────────────────────────────────────────────────────┐
   │ Pub/Sub: payments topic                                       │
   │ Event: "payment.completed"                                   │
   └───────────────────────────┬───────────────────────────────────┘
                               ▼
   ┌───────────────────────────────────────────────────────────────┐
   │ Subscription: notifications-from-payments                    │
   └───────────────────────────┬───────────────────────────────────┘
                               ▼
   ┌───────────────────────────────────────────────────────────────┐
   │ Notifications Service                                         │
   │ Process: Send payment receipt email                          │
   │ Log: "sending email to patient@example.com"                  │
   └───────────────────────────────────────────────────────────────┘

╔═══════════════════════════════════════════════════════════════════════╗
║                     IAM & SECURITY                                    ║
╚═══════════════════════════════════════════════════════════════════════╝

Service Account: runtime-sa@proyecto-cloud-native.iam.gserviceaccount.com

Roles Assigned:
┌─────────────────────────────────────────────────────────────────────┐
│ • roles/pubsub.publisher           → Publish to Pub/Sub topics     │
│ • roles/pubsub.subscriber          → Subscribe to Pub/Sub          │
│ • roles/cloudsql.client            → Connect to Cloud SQL          │
│ • roles/datastore.user             → Read/Write Firestore          │
│ • roles/storage.objectAdmin        → Read/Write Cloud Storage      │
│ • roles/logging.logWriter          → Write logs                    │
│ • roles/monitoring.metricWriter    → Write metrics                 │
│ • roles/cloudtrace.agent           → Write traces                  │
└─────────────────────────────────────────────────────────────────────┘

Public Access: Enabled for all services (no API Gateway yet)
└─ roles/run.invoker granted to allUsers (testing only)

╔═══════════════════════════════════════════════════════════════════════╗
║                        COST BREAKDOWN                                 ║
╚═══════════════════════════════════════════════════════════════════════╝

Development/Testing (Monthly):
┌─────────────────────────────────────────────────────────────────────┐
│ Cloud Run (7 services, ~1000 requests/day)      │ $5-10            │
│ Cloud SQL db-f1-micro (24/7)                    │ $7               │
│ Firestore (light usage, within free tier)       │ $0               │
│ Cloud Storage (4 buckets, ~5GB total)           │ $1-2             │
│ Pub/Sub (within free tier)                      │ $0               │
│ Monitoring & Logging (within free tier)         │ $0               │
│ ─────────────────────────────────────────────────────────────────── │
│ TOTAL                                            │ ~$15-20/month    │
└─────────────────────────────────────────────────────────────────────┘

Production Recommendations:
┌─────────────────────────────────────────────────────────────────────┐
│ • Upgrade Cloud SQL to db-custom-2-7680         │ ~$70/month       │
│ • Enable Cloud SQL read replica                 │ ~$70/month       │
│ • Cloud CDN for Storage                         │ ~$10/month       │
│ • Premium Cloud Run tier                        │ ~$20-50/month    │
│ ─────────────────────────────────────────────────────────────────── │
│ ESTIMATED PRODUCTION                             │ ~$170-200/month  │
└─────────────────────────────────────────────────────────────────────┘

╔═══════════════════════════════════════════════════════════════════════╗
║                    DEPLOYMENT TIMELINE                                ║
╚═══════════════════════════════════════════════════════════════════════╝

Phase 1: Container Builds (10-15 minutes)
  ├─ Build auth service
  ├─ Build appointments service
  ├─ Build payments service
  ├─ Build notifications service
  ├─ Build patients service
  ├─ Build doctors service
  └─ Build reporting service

Phase 2: Infrastructure Provisioning (5-10 minutes)
  ├─ Enable APIs
  ├─ Create Artifact Registry
  ├─ Create Cloud SQL instance
  ├─ Create Firestore database
  ├─ Create Cloud Storage buckets
  ├─ Create Pub/Sub topics & subscriptions
  ├─ Create IAM service account
  ├─ Deploy Cloud Run services
  ├─ Configure monitoring
  └─ Set up logging

Phase 3: Validation (2-3 minutes)
  ├─ Health checks
  ├─ Database connections
  ├─ Pub/Sub connectivity
  └─ Service URL generation

TOTAL DEPLOYMENT TIME: 15-25 minutes

╔═══════════════════════════════════════════════════════════════════════╗
║                        QUICK START                                    ║
╚═══════════════════════════════════════════════════════════════════════╝

1. Install Prerequisites
   $ brew install terraform jq

2. Validate Setup
   $ ./pre-deploy-check.sh

3. Deploy
   $ ./deploy.sh

4. Update Postman
   $ ./update-postman.sh

5. Health Check
   $ ./health-check.sh

6. Test E2E
   Import Postman collection and run tests

╔═══════════════════════════════════════════════════════════════════════╗
║                     MONITORING URLS                                   ║
╚═══════════════════════════════════════════════════════════════════════╝

After deployment, access:

🔗 Cloud Console
   https://console.cloud.google.com/home/dashboard?project=proyecto-cloud-native

📊 Monitoring Dashboard
   https://console.cloud.google.com/monitoring?project=proyecto-cloud-native

📝 Cloud Logging
   https://console.cloud.google.com/logs?project=proyecto-cloud-native

🔄 Cloud Run Services
   https://console.cloud.google.com/run?project=proyecto-cloud-native

🗄️  Cloud SQL
   https://console.cloud.google.com/sql?project=proyecto-cloud-native

📁 Firestore
   https://console.cloud.google.com/firestore?project=proyecto-cloud-native

💾 Cloud Storage
   https://console.cloud.google.com/storage?project=proyecto-cloud-native

📨 Pub/Sub
   https://console.cloud.google.com/cloudpubsub?project=proyecto-cloud-native

═══════════════════════════════════════════════════════════════════════════
                     ARCHITECTURE COMPLETE ✅
═══════════════════════════════════════════════════════════════════════════
