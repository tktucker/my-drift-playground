##──────────────────────────────────────────────────────────────
## Automated Drift Detector
##
## Architecture:
##   Cloud Scheduler (every 6h)
##     → triggers Cloud Build
##       → runs `terraform plan -detailed-exitcode`
##       → if exit code 2 (drift): logs structured message
##     → Log-based metric catches drift events
##     → Cloud Monitoring alert policy
##       → emails tktucker@gmail.com
##
## Cost: $0 (Cloud Build free tier = 120 min/day,
##        Cloud Scheduler free = 3 jobs/month,
##        Monitoring alerts = free)
##──────────────────────────────────────────────────────────────

##──────────────────────────────────────────────────────────────
## Service Account for Cloud Build drift checks
##──────────────────────────────────────────────────────────────

resource "google_service_account" "drift_detector_sa" {
  account_id   = "drift-detector-sa"
  display_name = "Drift Detector Service Account"
  description  = "SA used by Cloud Build to run terraform plan for drift detection"
  project      = var.project_id
}

# Cloud Build needs to read Terraform state from GCS
resource "google_storage_bucket_iam_member" "detector_state_reader" {
  bucket = google_storage_bucket.tf_state.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.drift_detector_sa.email}"
}

# Cloud Build needs read-only access to project resources to run `terraform plan`
resource "google_project_iam_member" "detector_viewer" {
  project = var.project_id
  role    = "roles/viewer"
  member  = "serviceAccount:${google_service_account.drift_detector_sa.email}"
}

# Allow Cloud Build to write logs (for the drift detection log entries)
resource "google_project_iam_member" "detector_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.drift_detector_sa.email}"
}

# Allow Cloud Build to run builds using this SA
resource "google_project_iam_member" "detector_build_sa" {
  project = var.project_id
  role    = "roles/cloudbuild.builds.editor"
  member  = "serviceAccount:${google_service_account.drift_detector_sa.email}"
}

# Allow Cloud Scheduler to invoke Cloud Build via HTTP
resource "google_project_iam_member" "detector_scheduler_invoker" {
  project = var.project_id
  role    = "roles/cloudbuild.builds.editor"
  member  = "serviceAccount:${google_service_account.scheduler_sa.email}"
}

##──────────────────────────────────────────────────────────────
## Scheduler Service Account
##──────────────────────────────────────────────────────────────

resource "google_service_account" "scheduler_sa" {
  account_id   = "drift-scheduler-sa"
  display_name = "Drift Scheduler Service Account"
  description  = "SA for Cloud Scheduler to trigger drift detection builds"
  project      = var.project_id
}

##──────────────────────────────────────────────────────────────
## Cloud Build Trigger — runs terraform plan
##
## We use a manual trigger (webhook-based) so Cloud Scheduler
## can kick it off on a cron. The build config is inline.
##──────────────────────────────────────────────────────────────

resource "google_cloudbuild_trigger" "drift_check" {
  name        = "drift-check"
  description = "Runs terraform plan to detect infrastructure drift"
  project     = var.project_id
  location    = var.region

  service_account = "projects/${var.project_id}/serviceAccounts/${google_service_account.drift_detector_sa.email}"

  # 2nd gen repository connection — source_to_build for manual trigger support
  source_to_build {
    repository = "projects/${var.project_id}/locations/${var.region}/connections/${var.repo_connection}/repositories/${var.repo_name}"
    ref        = "refs/heads/${var.repo_branch}"
    repo_type  = "GITHUB"
  }

  git_file_source {
    path       = "cloudbuild-drift.yaml"
    repository = "projects/${var.project_id}/locations/${var.region}/connections/${var.repo_connection}/repositories/${var.repo_name}"
    revision   = "refs/heads/${var.repo_branch}"
    repo_type  = "GITHUB"
  }

  substitutions = {
    _PROJECT_ID     = var.project_id
    _STATE_BUCKET   = google_storage_bucket.tf_state.name
    _REGION         = var.region
    _ALERT_EMAIL    = var.alert_email
    _REPO_CONNECTION = var.repo_connection
    _REPO_NAME      = var.repo_name
    _REPO_BRANCH    = var.repo_branch
  }

  depends_on = [google_project_service.apis]
}

##──────────────────────────────────────────────────────────────
## Cloud Scheduler — triggers the drift check every 6 hours
##──────────────────────────────────────────────────────────────

resource "google_cloud_scheduler_job" "drift_check_cron" {
  name        = "drift-check-every-6h"
  description = "Triggers drift detection Cloud Build job every 6 hours"
  project     = var.project_id
  region      = var.region

  schedule  = "0 */6 * * *"     # every 6 hours
  time_zone = "America/Chicago"

  http_target {
    http_method = "POST"
    uri         = "https://cloudbuild.googleapis.com/v1/projects/${var.project_id}/locations/${var.region}/triggers/${google_cloudbuild_trigger.drift_check.trigger_id}:run"
    body        = base64encode(jsonencode({ source = { branch = var.repo_branch } }))

    headers = {
      "Content-Type" = "application/json"
    }

    oauth_token {
      service_account_email = google_service_account.scheduler_sa.email
    }
  }

  retry_config {
    retry_count = 1
  }

  depends_on = [google_project_service.apis]
}
