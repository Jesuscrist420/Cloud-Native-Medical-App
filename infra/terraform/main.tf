terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.34"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable core APIs for deployments
resource "google_project_service" "services" {
  for_each = toset([
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "pubsub.googleapis.com",
    "sqladmin.googleapis.com",
    "cloudbuild.googleapis.com",
    "firestore.googleapis.com",
    "storage.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "cloudtrace.googleapis.com"
  ])
  service            = each.value
  disable_on_destroy = false
}

# Artifact Registry for container images
resource "google_artifact_registry_repository" "containers" {
  location      = var.region
  repository_id = "medical-app"
  format        = "DOCKER"
  description   = "Container images for Cloud-Native Medical App"
  depends_on    = [google_project_service.services]
}

# Pub/Sub Topics
resource "google_pubsub_topic" "appointments" { name = "appointments" }
resource "google_pubsub_topic" "payments"     { name = "payments" }
resource "google_pubsub_topic" "notifications"{ name = "notifications" }

# Subscriptions (services can add more as needed)
resource "google_pubsub_subscription" "notifications_service" {
  name  = "notifications-service"
  topic = google_pubsub_topic.notifications.name
}

# Subscriptions for bridge from other domains to notifications
resource "google_pubsub_subscription" "notifications_from_appointments" {
  name  = "notifications-from-appointments"
  topic = google_pubsub_topic.appointments.name
}

resource "google_pubsub_subscription" "notifications_from_payments" {
  name  = "notifications-from-payments"
  topic = google_pubsub_topic.payments.name
}

# Runtime Service Account for Cloud Run
resource "google_service_account" "runtime" {
  account_id   = "runtime-sa"
  display_name = "Cloud Run runtime SA"
}

# Grant Pub/Sub permissions
resource "google_project_iam_member" "runtime_pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.runtime.email}"
}

resource "google_project_iam_member" "runtime_pubsub_subscriber" {
  project = var.project_id
  role    = "roles/pubsub.subscriber"
  member  = "serviceAccount:${google_service_account.runtime.email}"
}

# Grant Cloud SQL permissions
resource "google_project_iam_member" "runtime_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.runtime.email}"
}

# Grant Firestore permissions
resource "google_project_iam_member" "runtime_firestore_user" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.runtime.email}"
}

# Grant Cloud Storage permissions
resource "google_project_iam_member" "runtime_storage_admin" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.runtime.email}"
}

# Grant Logging permissions
resource "google_project_iam_member" "runtime_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.runtime.email}"
}

# Grant Monitoring permissions
resource "google_project_iam_member" "runtime_monitoring_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.runtime.email}"
}

# Grant Cloud Trace permissions
resource "google_project_iam_member" "runtime_trace_agent" {
  project = var.project_id
  role    = "roles/cloudtrace.agent"
  member  = "serviceAccount:${google_service_account.runtime.email}"
}

locals {
  artifact_repo = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.containers.repository_id}"
}

# =============================================================================
# CLOUD RUN SERVICES
# =============================================================================

locals {
  common_env = [
    { name = "GOOGLE_CLOUD_PROJECT", value = var.project_id },
    { name = "PORT", value = "8080" },
    { name = "GCP_REGION", value = var.region }
  ]
}

# Auth Service - Firestore
resource "google_cloud_run_v2_service" "auth" {
  name     = "auth"
  location = var.region
  template {
    service_account = google_service_account.runtime.email
    containers {
      image = "${local.artifact_repo}/auth:latest"
      
      dynamic "env" {
        for_each = local.common_env
        content {
          name  = env.value.name
          value = env.value.value
        }
      }
      
      env {
        name  = "DATABASE_TYPE"
        value = "FIRESTORE"
      }
      
      ports { container_port = 8080 }
    }
  }
  depends_on = [google_project_service.services, google_firestore_database.auth_db]
}

# Patients Service - Firestore + Cloud Storage
resource "google_cloud_run_v2_service" "patients" {
  name     = "patients"
  location = var.region
  template {
    service_account = google_service_account.runtime.email
    containers {
      image = "${local.artifact_repo}/patients:latest"
      
      dynamic "env" {
        for_each = local.common_env
        content {
          name  = env.value.name
          value = env.value.value
        }
      }
      
      env {
        name  = "DATABASE_TYPE"
        value = "FIRESTORE"
      }
      
      env {
        name  = "STORAGE_BUCKET"
        value = google_storage_bucket.patients_bucket.name
      }
      
      ports { container_port = 8080 }
    }
  }
  depends_on = [google_project_service.services, google_storage_bucket.patients_bucket]
}

# Doctors Service - Firestore + Cloud Storage
resource "google_cloud_run_v2_service" "doctors" {
  name     = "doctors"
  location = var.region
  template {
    service_account = google_service_account.runtime.email
    containers {
      image = "${local.artifact_repo}/doctors:latest"
      
      dynamic "env" {
        for_each = local.common_env
        content {
          name  = env.value.name
          value = env.value.value
        }
      }
      
      env {
        name  = "DATABASE_TYPE"
        value = "FIRESTORE"
      }
      
      env {
        name  = "STORAGE_BUCKET"
        value = google_storage_bucket.doctors_bucket.name
      }
      
      ports { container_port = 8080 }
    }
  }
  depends_on = [google_project_service.services, google_storage_bucket.doctors_bucket]
}

# Reporting Service - Cloud Storage only
resource "google_cloud_run_v2_service" "reporting" {
  name     = "reporting"
  location = var.region
  template {
    service_account = google_service_account.runtime.email
    containers {
      image = "${local.artifact_repo}/reporting:latest"
      
      dynamic "env" {
        for_each = local.common_env
        content {
          name  = env.value.name
          value = env.value.value
        }
      }
      
      env {
        name  = "STORAGE_BUCKET"
        value = google_storage_bucket.reporting_bucket.name
      }
      
      ports { container_port = 8080 }
    }
  }
  depends_on = [google_project_service.services, google_storage_bucket.reporting_bucket]
}

# Appointments Service - Cloud SQL + Pub/Sub
resource "google_cloud_run_v2_service" "appointments" {
  name     = "appointments"
  location = var.region
  template {
    service_account = google_service_account.runtime.email
    containers {
      image = "${local.artifact_repo}/appointments:latest"
      
      dynamic "env" {
        for_each = local.common_env
        content {
          name  = env.value.name
          value = env.value.value
        }
      }
      
      env {
        name  = "DATABASE_TYPE"
        value = "POSTGRES"
      }
      
      env {
        name  = "DB_HOST"
        value = google_sql_database_instance.primary.public_ip_address
      }
      
      env {
        name  = "DB_NAME"
        value = google_sql_database.appointments_db.name
      }
      
      env {
        name  = "DB_USER"
        value = google_sql_user.medical_app_user.name
      }
      
      env {
        name  = "DB_PASSWORD"
        value = var.db_password
      }
      
      env {
        name  = "DB_CONNECTION_NAME"
        value = google_sql_database_instance.primary.connection_name
      }
      
      env {
        name  = "TOPIC_APPOINTMENTS"
        value = google_pubsub_topic.appointments.name
      }
      
      ports { container_port = 8080 }
    }
  }
  depends_on = [google_project_service.services, google_sql_database.appointments_db]
}

# Payments Service - Cloud SQL + Pub/Sub
resource "google_cloud_run_v2_service" "payments" {
  name     = "payments"
  location = var.region
  template {
    service_account = google_service_account.runtime.email
    containers {
      image = "${local.artifact_repo}/payments:latest"
      
      dynamic "env" {
        for_each = local.common_env
        content {
          name  = env.value.name
          value = env.value.value
        }
      }
      
      env {
        name  = "DATABASE_TYPE"
        value = "POSTGRES"
      }
      
      env {
        name  = "DB_HOST"
        value = google_sql_database_instance.primary.public_ip_address
      }
      
      env {
        name  = "DB_NAME"
        value = google_sql_database.payments_db.name
      }
      
      env {
        name  = "DB_USER"
        value = google_sql_user.medical_app_user.name
      }
      
      env {
        name  = "DB_PASSWORD"
        value = var.db_password
      }
      
      env {
        name  = "DB_CONNECTION_NAME"
        value = google_sql_database_instance.primary.connection_name
      }
      
      env {
        name  = "TOPIC_PAYMENTS"
        value = google_pubsub_topic.payments.name
      }
      
      ports { container_port = 8080 }
    }
  }
  depends_on = [google_project_service.services, google_sql_database.payments_db]
}

# Notifications Service - No database, Pub/Sub subscriber
resource "google_cloud_run_v2_service" "notifications" {
  name     = "notifications"
  location = var.region
  template {
    service_account = google_service_account.runtime.email
    scaling { min_instance_count = 1 }
    containers {
      image = "${local.artifact_repo}/notifications:latest"
      
      dynamic "env" {
        for_each = local.common_env
        content {
          name  = env.value.name
          value = env.value.value
        }
      }
      
      env {
        name  = "TOPIC_NOTIFICATIONS"
        value = google_pubsub_topic.notifications.name
      }
      
      env {
        name  = "TOPIC_APPOINTMENTS"
        value = google_pubsub_topic.appointments.name
      }
      
      env {
        name  = "TOPIC_PAYMENTS"
        value = google_pubsub_topic.payments.name
      }
      
      env {
        name  = "SUB_NOTIFICATIONS"
        value = google_pubsub_subscription.notifications_service.name
      }
      
      env {
        name  = "SUB_NOTIF_FROM_APPTS"
        value = google_pubsub_subscription.notifications_from_appointments.name
      }
      
      env {
        name  = "SUB_NOTIF_FROM_PAYMENTS"
        value = google_pubsub_subscription.notifications_from_payments.name
      }
      
      ports { container_port = 8080 }
    }
  }
  depends_on = [google_project_service.services]
}

# Allow public invocations for quick testing (no gateway yet)
resource "google_cloud_run_v2_service_iam_member" "auth_invoker" {
  name     = google_cloud_run_v2_service.auth.name
  location = var.region
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "patients_invoker" {
  name     = google_cloud_run_v2_service.patients.name
  location = var.region
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "doctors_invoker" {
  name     = google_cloud_run_v2_service.doctors.name
  location = var.region
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "reporting_invoker" {
  name     = google_cloud_run_v2_service.reporting.name
  location = var.region
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "appointments_invoker" {
  name     = google_cloud_run_v2_service.appointments.name
  location = var.region
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "payments_invoker" {
  name     = google_cloud_run_v2_service.payments.name
  location = var.region
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "notifications_invoker" {
  name     = google_cloud_run_v2_service.notifications.name
  location = var.region
  role     = "roles/run.invoker"
  member   = "allUsers"
}
# =============================================================================
# DATABASE INFRASTRUCTURE
# =============================================================================

# 1. Firestore (Native Mode) for Auth Service
resource "google_firestore_database" "auth_db" {
  project     = var.project_id
  name        = "(default)"
  location_id = var.region
  type        = "FIRESTORE_NATIVE"

  depends_on = [google_project_service.services]
}

# 2. Cloud SQL (PostgreSQL) for Appointments & Payments
resource "google_sql_database_instance" "primary" {
  name             = "healthcare-sql"
  database_version = "POSTGRES_15"
  region           = var.region

  settings {
    tier = "db-f1-micro"
    
    backup_configuration {
      enabled = true
      start_time = "03:00"
    }

    ip_configuration {
      ipv4_enabled = true
      authorized_networks {
        name  = "allow-all-temp"
        value = "0.0.0.0/0"
      }
    }
  }

  deletion_protection = false
  depends_on         = [google_project_service.services]
}

# Create databases for SQL services
resource "google_sql_database" "appointments_db" {
  name     = "appointments"
  instance = google_sql_database_instance.primary.name
}

resource "google_sql_database" "payments_db" {
  name     = "payments"
  instance = google_sql_database_instance.primary.name
}

# Create SQL user
resource "google_sql_user" "medical_app_user" {
  name     = "medical-app"
  instance = google_sql_database_instance.primary.name
  password = var.db_password
}

# 3. Cloud Storage Buckets
# Reporting service bucket
resource "google_storage_bucket" "reporting_bucket" {
  name     = "${var.project_id}-reporting"
  location = var.region
  
  uniform_bucket_level_access = true
  
  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 365  # Delete reports older than 1 year
    }
  }

  depends_on = [google_project_service.services]
}

# Patients documents bucket
resource "google_storage_bucket" "patients_bucket" {
  name     = "${var.project_id}-patients-documents"
  location = var.region
  
  uniform_bucket_level_access = true
  
  versioning {
    enabled = true
  }

  depends_on = [google_project_service.services]
}

# Doctors documents bucket  
resource "google_storage_bucket" "doctors_bucket" {
  name     = "${var.project_id}-doctors-documents"
  location = var.region
  
  uniform_bucket_level_access = true
  
  versioning {
    enabled = true
  }

  depends_on = [google_project_service.services]
}

# =============================================================================
# OBSERVABILITY - LOG SINKS & METRICS
# =============================================================================

# Create a log sink for application logs
resource "google_logging_project_sink" "app_logs_sink" {
  name        = "medical-app-logs"
  destination = "storage.googleapis.com/${google_storage_bucket.logs_bucket.name}"
  
  filter = <<-EOT
    resource.type="cloud_run_revision"
    resource.labels.service_name=~"(auth|appointments|payments|notifications|patients|doctors|reporting)"
  EOT

  unique_writer_identity = true
}

# Bucket for log storage
resource "google_storage_bucket" "logs_bucket" {
  name     = "${var.project_id}-application-logs"
  location = var.region
  
  uniform_bucket_level_access = true
  
  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 90  # Keep logs for 90 days
    }
  }

  depends_on = [google_project_service.services]
}

# Grant log sink permissions
resource "google_storage_bucket_iam_member" "logs_sink_writer" {
  bucket = google_storage_bucket.logs_bucket.name
  role   = "roles/storage.objectCreator"
  member = google_logging_project_sink.app_logs_sink.writer_identity
}

# Custom metrics for monitoring
resource "google_monitoring_alert_policy" "high_error_rate" {
  display_name = "High Error Rate - Medical App"
  combiner     = "OR"
  
  conditions {
    display_name = "Error rate above 5%"
    
    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/request_count\" AND metric.labels.response_code_class=\"5xx\""
      duration        = "60s"
      comparison      = "COMPARISON_GT"
      threshold_value = 5
      
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = []
  
  alert_strategy {
    auto_close = "1800s"
  }

  depends_on = [google_project_service.services]
}

# Dashboard for service health
resource "google_monitoring_dashboard" "medical_app_dashboard" {
  dashboard_json = jsonencode({
    displayName = "Medical App - Service Health"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "Request Count by Service"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/request_count\""
                    aggregation = {
                      alignmentPeriod  = "60s"
                      perSeriesAligner = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields = ["resource.label.service_name"]
                    }
                  }
                }
              }]
            }
          }
        },
        {
          xPos   = 6
          width  = 6
          height = 4
          widget = {
            title = "Error Rate by Service"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/request_count\" AND metric.labels.response_code_class=\"5xx\""
                    aggregation = {
                      alignmentPeriod  = "60s"
                      perSeriesAligner = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields = ["resource.label.service_name"]
                    }
                  }
                }
              }]
            }
          }
        },
        {
          yPos   = 4
          width  = 6
          height = 4
          widget = {
            title = "Request Latency (p95)"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/request_latencies\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_DELTA"
                      crossSeriesReducer = "REDUCE_PERCENTILE_95"
                      groupByFields      = ["resource.label.service_name"]
                    }
                  }
                }
              }]
            }
          }
        },
        {
          xPos   = 6
          yPos   = 4
          width  = 6
          height = 4
          widget = {
            title = "Container Instance Count"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/container/instance_count\""
                    aggregation = {
                      alignmentPeriod  = "60s"
                      perSeriesAligner = "ALIGN_MEAN"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields = ["resource.label.service_name"]
                    }
                  }
                }
              }]
            }
          }
        }
      ]
    }
  })

  depends_on = [google_project_service.services]
}

# =============================================================================
# PUB/SUB TOPICS & SUBSCRIPTIONS
# =============================================================================