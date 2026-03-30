##──────────────────────────────────────────────────────────────
## Service Account & IAM — The #1 real-world drift source
##
## This is where drift happens most in production:
##   "I just need to add this one role real quick..."
##   *clicks in IAM console* → drift.
##
## Drift targets:
##   • Add an extra role to the SA in the console
##   • Change the display name or description
##   • Grant the SA access to another resource
##   • Add a new SA key via the console (dangerous IRL!)
##   • Add a condition to an IAM binding
##──────────────────────────────────────────────────────────────

# Dedicated service account for the drift playground workloads
resource "google_service_account" "drift_sa" {
  account_id   = "drift-playground-sa"
  display_name = "Drift Playground Service Account"
  description  = "SA for drift playground workloads and drift detection"
  project      = var.project_id
}

# Role: Allow the SA to invoke Cloud Run services
resource "google_project_iam_member" "drift_sa_run_invoker" {
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.drift_sa.email}"
}

# Role: Allow the SA to write logs
resource "google_project_iam_member" "drift_sa_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.drift_sa.email}"
}

# Role: Allow the SA to publish metrics
resource "google_project_iam_member" "drift_sa_monitoring_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.drift_sa.email}"
}

# Role: Allow the SA to read Terraform state from the state bucket
resource "google_storage_bucket_iam_member" "drift_sa_state_reader" {
  bucket = google_storage_bucket.tf_state.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.drift_sa.email}"
}

##──────────────────────────────────────────────────────────────
## Outputs
##──────────────────────────────────────────────────────────────

output "service_account_email" {
  description = "Email of the drift playground service account"
  value       = google_service_account.drift_sa.email
}
