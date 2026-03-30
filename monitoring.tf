##──────────────────────────────────────────────────────────────
## Monitoring — Log-based metric + Alert Policy + Email
##
## This catches the structured log "DRIFT_DETECTED" written by
## the Cloud Build job and fires an email to you.
##──────────────────────────────────────────────────────────────

##──────────────────────────────────────────────────────────────
## Email Notification Channel
##──────────────────────────────────────────────────────────────

resource "google_monitoring_notification_channel" "drift_email" {
  display_name = "Drift Alert — Tom"
  type         = "email"
  project      = var.project_id

  labels = {
    email_address = var.alert_email
  }

  user_labels = local.base_labels
}

##──────────────────────────────────────────────────────────────
## Log-based Metric — counts "DRIFT_DETECTED" log entries
##──────────────────────────────────────────────────────────────

resource "google_logging_metric" "drift_detected" {
  name    = "drift-detected-count"
  project = var.project_id

  description = "Counts drift detection events from Cloud Build terraform plan runs"

  filter = <<-EOT
    resource.type="build"
    textPayload=~"DRIFT_DETECTED"
  EOT

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"

    labels {
      key         = "severity"
      value_type  = "STRING"
      description = "Severity of the drift event"
    }
  }

  label_extractors = {
    "severity" = "EXTRACT(jsonPayload.severity)"
  }
}

##──────────────────────────────────────────────────────────────
## Alert Policy — fires when drift count > 0
##──────────────────────────────────────────────────────────────

resource "google_monitoring_alert_policy" "drift_alert" {
  display_name = "Terraform Drift Detected"
  project      = var.project_id
  combiner     = "OR"

  conditions {
    display_name = "Drift detected in terraform plan"

    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/${google_logging_metric.drift_detected.name}\" AND resource.type=\"build\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "0s"

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_SUM"
      }

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [
    google_monitoring_notification_channel.drift_email.name
  ]

  alert_strategy {
    auto_close = "1800s" # auto-close after 30 min
  }

  documentation {
    content   = <<-EOT
      ## Terraform State Drift Detected

      The automated drift detector found differences between your
      Terraform state and the actual GCP infrastructure.

      **What to do:**
      1. Check the Cloud Build logs for the full `terraform plan` output
      2. Identify what changed and whether it was intentional
      3. Either:
         - Run `terraform apply` to bring infrastructure back in line, OR
         - Update your `.tf` files to match the desired new state

      **Cloud Build logs:**
      https://console.cloud.google.com/cloud-build/builds?project=${var.project_id}
    EOT
    mime_type = "text/markdown"
  }

  user_labels = local.base_labels

  depends_on = [google_project_service.apis]
}
