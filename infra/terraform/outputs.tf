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

output "artifact_registry_repo" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.containers.repository_id}"
}
