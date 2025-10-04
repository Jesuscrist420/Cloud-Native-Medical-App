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
    "cloudbuild.googleapis.com"
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

# Grant minimal Pub/Sub permissions
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

locals {
  artifact_repo = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.containers.repository_id}"
}

# Cloud Run v2 services
resource "google_cloud_run_v2_service" "appointments" {
  name     = "appointments"
  location = var.region
  template {
    service_account = google_service_account.runtime.email
    containers {
      image = "${local.artifact_repo}/appointments:latest"
      env {
        name  = "GOOGLE_CLOUD_PROJECT"
        value = var.project_id
      }
      env {
        name  = "TOPIC_APPOINTMENTS"
        value = google_pubsub_topic.appointments.name
      }
      ports { container_port = 8080 }
    }
  }
  depends_on = [google_project_service.services]
}

resource "google_cloud_run_v2_service" "payments" {
  name     = "payments"
  location = var.region
  template {
    service_account = google_service_account.runtime.email
    containers {
      image = "${local.artifact_repo}/payments:latest"
      env {
        name  = "GOOGLE_CLOUD_PROJECT"
        value = var.project_id
      }
      env {
        name  = "TOPIC_PAYMENTS"
        value = google_pubsub_topic.payments.name
      }
      ports { container_port = 8080 }
    }
  }
  depends_on = [google_project_service.services]
}

resource "google_cloud_run_v2_service" "notifications" {
  name     = "notifications"
  location = var.region
  template {
    service_account = google_service_account.runtime.email
    scaling { min_instance_count = 1 }
    containers {
      image = "${local.artifact_repo}/notifications:latest"
      env {
        name  = "GOOGLE_CLOUD_PROJECT"
        value = var.project_id
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
# Cloud SQL Instance (PostgreSQL)
resource "google_sql_database_instance" "primary" {
  name             = "healthcare-sql"
  database_version = "POSTGRES_15"
  region           = var.region

  settings {
    tier = "db-f1-micro"
  }
}

# Per-service databases
locals {
  service_dbs = [
    "auth",
    "appointments",
    "payments",
    "notifications",
    "reporting",
    "patients",
    "doctors"
  ]
}

resource "google_sql_database" "service_dbs" {
  for_each = toset(local.service_dbs)
  name     = each.value
  instance = google_sql_database_instance.primary.name
}
