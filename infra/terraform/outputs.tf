output "pubsub_topics" {
  value = [
    google_pubsub_topic.appointments.name,
    google_pubsub_topic.payments.name,
    google_pubsub_topic.notifications.name,
  ]
}

output "cloud_sql_instance" {
  value = google_sql_database_instance.primary.name
}

output "cloud_sql_connection_name" {
  value = google_sql_database_instance.primary.connection_name
}

output "cloud_sql_ip" {
  value = google_sql_database_instance.primary.public_ip_address
}

output "artifact_registry_repo" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.containers.repository_id}"
}

output "firestore_database" {
  value = google_firestore_database.auth_db.name
}

output "storage_buckets" {
  description = "Cloud Storage buckets by service"
  value = {
    patients  = google_storage_bucket.patients_bucket.name
    doctors   = google_storage_bucket.doctors_bucket.name
    reporting = google_storage_bucket.reporting_bucket.name
    logs      = google_storage_bucket.logs_bucket.name
  }
}

output "service_urls" {
  description = "Cloud Run service URLs for E2E testing"
  value = {
    auth          = google_cloud_run_v2_service.auth.uri
    patients      = google_cloud_run_v2_service.patients.uri
    doctors       = google_cloud_run_v2_service.doctors.uri
    appointments  = google_cloud_run_v2_service.appointments.uri
    payments      = google_cloud_run_v2_service.payments.uri
    notifications = google_cloud_run_v2_service.notifications.uri
    reporting     = google_cloud_run_v2_service.reporting.uri
  }
}

output "observability_links" {
  description = "Links to monitoring and logging dashboards"
  value = {
    cloud_console      = "https://console.cloud.google.com/home/dashboard?project=${var.project_id}"
    cloud_run          = "https://console.cloud.google.com/run?project=${var.project_id}"
    monitoring         = "https://console.cloud.google.com/monitoring/dashboards/custom/${google_monitoring_dashboard.medical_app_dashboard.id}?project=${var.project_id}"
    logs               = "https://console.cloud.google.com/logs/query?project=${var.project_id}"
    pubsub             = "https://console.cloud.google.com/cloudpubsub/topic/list?project=${var.project_id}"
    cloud_sql          = "https://console.cloud.google.com/sql/instances?project=${var.project_id}"
    firestore          = "https://console.cloud.google.com/firestore/databases/-default-/data?project=${var.project_id}"
    storage            = "https://console.cloud.google.com/storage/browser?project=${var.project_id}"
  }
}

output "database_summary" {
  description = "Database assignments per service"
  value = {
    auth         = "Firestore (Native Mode)"
    appointments = "Cloud SQL PostgreSQL - Database: appointments"
    payments     = "Cloud SQL PostgreSQL - Database: payments"
    notifications = "None (stateless event-driven service)"
    patients     = "Firestore + Cloud Storage: ${google_storage_bucket.patients_bucket.name}"
    doctors      = "Firestore + Cloud Storage: ${google_storage_bucket.doctors_bucket.name}"
    reporting    = "Cloud Storage: ${google_storage_bucket.reporting_bucket.name}"
  }
}

output "deployment_summary" {
  description = "Quick deployment summary"
  value = <<-EOT
  
  ==========================================
  🚀 Cloud-Native Medical App Deployed!
  ==========================================
  
  Project: ${var.project_id}
  Region: ${var.region}
  
  📦 Container Registry:
  ${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.containers.repository_id}
  
  🔗 Service Endpoints:
  - Auth:          ${google_cloud_run_v2_service.auth.uri}
  - Patients:      ${google_cloud_run_v2_service.patients.uri}
  - Doctors:       ${google_cloud_run_v2_service.doctors.uri}
  - Appointments:  ${google_cloud_run_v2_service.appointments.uri}
  - Payments:      ${google_cloud_run_v2_service.payments.uri}
  - Notifications: ${google_cloud_run_v2_service.notifications.uri}
  - Reporting:     ${google_cloud_run_v2_service.reporting.uri}
  
  📊 Pub/Sub Topics:
  - ${google_pubsub_topic.appointments.name}
  - ${google_pubsub_topic.payments.name}
  - ${google_pubsub_topic.notifications.name}
  
  🗄️  Databases:
  - Auth:          Firestore (Native Mode)
  - Appointments:  Cloud SQL PostgreSQL (${google_sql_database_instance.primary.connection_name})
  - Payments:      Cloud SQL PostgreSQL (${google_sql_database_instance.primary.connection_name})
  - Patients:      Firestore + Bucket (${google_storage_bucket.patients_bucket.name})
  - Doctors:       Firestore + Bucket (${google_storage_bucket.doctors_bucket.name})
  - Reporting:     Bucket (${google_storage_bucket.reporting_bucket.name})
  - Notifications: None (stateless)
  
  📈 Observability:
  - Dashboard:     ${google_monitoring_dashboard.medical_app_dashboard.id}
  - Alert Policy:  ${google_monitoring_alert_policy.high_error_rate.name}
  - Log Sink:      ${google_logging_project_sink.app_logs_sink.name}
  - Logs Bucket:   ${google_storage_bucket.logs_bucket.name}
  
  🔍 Quick Links:
  - Monitoring:    https://console.cloud.google.com/monitoring/dashboards/custom/${google_monitoring_dashboard.medical_app_dashboard.id}?project=${var.project_id}
  - Cloud Logging: https://console.cloud.google.com/logs/query?project=${var.project_id}
  - Cloud Run:     https://console.cloud.google.com/run?project=${var.project_id}
  
  ⚠️  Next Steps:
  1. Test health endpoints: curl <service-url>/healthz
  2. Run: ./update-postman.sh
  3. Import Postman collection and test E2E flow
  4. View logs: gcloud run services logs read <service> --region=${var.region}
  
  ==========================================
  EOT
}
