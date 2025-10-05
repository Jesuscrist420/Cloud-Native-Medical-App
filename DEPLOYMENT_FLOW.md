# Deployment Flow Comparison

## Full Deployment (`./deploy.sh`)

```
┌─────────────────────────────────────────────────────────────┐
│                     FULL DEPLOYMENT                         │
└─────────────────────────────────────────────────────────────┘

📋 Set GCP Project
    ↓
🔨 Build Container Images (7-10 min)
    ├─ auth
    ├─ appointments  
    ├─ payments
    ├─ notifications
    ├─ patients
    ├─ doctors
    └─ reporting
    ↓
🏗️  Deploy Infrastructure (5-10 min)
    ├─ Terraform Init
    ├─ Terraform Plan
    └─ Terraform Apply
         ├─ Cloud Run Services (7)
         ├─ Cloud SQL (PostgreSQL)
         ├─ Firestore Database
         ├─ Storage Buckets (4)
         ├─ Pub/Sub Topics (3)
         ├─ Pub/Sub Subscriptions (3)
         ├─ Monitoring Dashboard
         ├─ Alert Policies
         └─ IAM Permissions
    ↓
✅ Deployment Complete!
    ↓
📝 Display Service URLs

Total Time: 15-20 minutes
```

## Infrastructure-Only Deployment (`./deploy.sh --skip-build`)

```
┌─────────────────────────────────────────────────────────────┐
│              INFRASTRUCTURE-ONLY DEPLOYMENT                 │
└─────────────────────────────────────────────────────────────┘

📋 Set GCP Project
    ↓
⏭️  Skip Container Builds (0 min)
    ↓
🏗️  Deploy Infrastructure (5-10 min)
    ├─ Terraform Init
    ├─ Terraform Plan
    └─ Terraform Apply
         ├─ Cloud Run Services (7)
         │   └─ Uses existing container images
         ├─ Cloud SQL (PostgreSQL)
         ├─ Firestore Database
         ├─ Storage Buckets (4)
         ├─ Pub/Sub Topics (3)
         ├─ Pub/Sub Subscriptions (3)
         ├─ Monitoring Dashboard
         ├─ Alert Policies
         └─ IAM Permissions
    ↓
✅ Deployment Complete!
    ↓
📝 Display Service URLs

Total Time: 5-10 minutes (50-66% faster!)
```

## Decision Tree

```
                    Start Deployment
                           |
                           |
         ┌─────────────────┴──────────────────┐
         |                                    |
    Code Changed?                       Only Config?
         |                                    |
         |                                    |
        YES                                  YES
         |                                    |
         ↓                                    ↓
  Need to rebuild              Use existing containers
    containers                   from registry
         |                                    |
         ↓                                    ↓
   ./deploy.sh              ./deploy.sh --skip-build
         |                                    |
         ↓                                    ↓
  Build + Deploy                      Deploy Only
   (15-20 min)                         (5-10 min)
         |                                    |
         └─────────────────┬──────────────────┘
                           |
                           ↓
                   Services Running! ✅
```

## Use Case Matrix

| Scenario | Command | Time | Reason |
|----------|---------|------|--------|
| 🆕 First deployment | `./deploy.sh` | 15-20m | Need to build everything |
| 🐛 Fixed service bug | `./deploy.sh` | 15-20m | Code changed, rebuild needed |
| ➕ New feature added | `./deploy.sh` | 15-20m | Code changed, rebuild needed |
| 🔧 Updated env vars | `./deploy.sh --skip-build` | 5-10m | Config only, reuse containers |
| 💾 Added database | `./deploy.sh --skip-build` | 5-10m | Infrastructure only |
| 🪣 New storage bucket | `./deploy.sh --skip-build` | 5-10m | Infrastructure only |
| 🔐 Changed IAM policy | `./deploy.sh --skip-build` | 5-10m | Infrastructure only |
| 📊 Updated monitoring | `./deploy.sh --skip-build` | 5-10m | Infrastructure only |
| 🔄 Terraform refactor | `./deploy.sh --skip-build` | 5-10m | Config only, reuse containers |

## Component Deployment Matrix

| Component | Full Deploy | Skip Build |
|-----------|-------------|------------|
| Container Images | ✅ Build & Push | ⏭️ Skip (use existing) |
| Cloud Run Services | ✅ Deploy | ✅ Deploy |
| Cloud SQL | ✅ Deploy | ✅ Deploy |
| Firestore | ✅ Deploy | ✅ Deploy |
| Storage Buckets | ✅ Deploy | ✅ Deploy |
| Pub/Sub | ✅ Deploy | ✅ Deploy |
| Monitoring | ✅ Deploy | ✅ Deploy |
| IAM | ✅ Deploy | ✅ Deploy |

## Performance Breakdown

### Full Deployment Timeline
```
0:00  ──→ Start
0:01  ──→ Set GCP Project ✓
       |
0:01  ──→ Build auth container
1:30  ──→ Build appointments container  
2:30  ──→ Build payments container
3:30  ──→ Build notifications container
4:30  ──→ Build patients container
5:30  ──→ Build doctors container
6:30  ──→ Build reporting container
       |
8:00  ──→ Terraform init ✓
8:15  ──→ Terraform plan ✓
8:30  ──→ User confirms deployment
       |
8:30  ──→ Deploy Cloud SQL (largest operation)
       |    ├─ Create instance (10-12 min)
       |    ├─ Create databases
       |    └─ Create user
       |
20:00 ──→ Deploy remaining resources
       |    ├─ Firestore
       |    ├─ Storage Buckets
       |    ├─ Pub/Sub
       |    ├─ Cloud Run Services
       |    ├─ Monitoring
       |    └─ IAM
       |
22:00 ──→ Complete! ✅
```

### Infrastructure-Only Timeline
```
0:00  ──→ Start
0:01  ──→ Set GCP Project ✓
       |
0:01  ──→ Skip builds ⏭️
       |
0:02  ──→ Terraform init ✓
0:15  ──→ Terraform plan ✓
0:30  ──→ User confirms deployment
       |
0:30  ──→ Deploy/Update all resources
       |    ├─ Update Cloud Run configs
       |    ├─ Update storage buckets
       |    ├─ Update Pub/Sub
       |    ├─ Update monitoring
       |    └─ Update IAM
       |
8:00  ──→ Complete! ✅
```

## Cost Comparison

### Cloud Build Costs (Approximate)

**Full Deployment:**
- 7 services × 1 minute build = ~7 build-minutes
- First 120 minutes/day free
- Subsequent: $0.003/build-minute
- Cost per deployment after free tier: ~$0.02

**Infrastructure-Only:**
- 0 build-minutes
- Cost: $0.00 (no builds)

**Monthly savings example:**
- 5 deployments/day × 30 days = 150 deployments
- If 70% are config-only (105 deployments)
- Savings: 105 × 7 min = 735 build-minutes saved
- Cost savings: ~$2.21/month (after free tier)

## Summary

```
┌─────────────────────────────────────────────────────────────┐
│                   QUICK REFERENCE                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Full Deployment                                            │
│  $ ./deploy.sh                                              │
│  ⏱️  15-20 minutes                                          │
│  💰 ~7 build-minutes                                        │
│                                                             │
│  ─────────────────────────────────────────────────────     │
│                                                             │
│  Infrastructure Only                                        │
│  $ ./deploy.sh --skip-build                                 │
│  ⏱️  5-10 minutes (50-66% faster!)                          │
│  💰 0 build-minutes                                         │
│                                                             │
│  ─────────────────────────────────────────────────────     │
│                                                             │
│  Help                                                       │
│  $ ./deploy.sh --help                                       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```
