##──────────────────────────────────────────────────────────────
## Summary Outputs
##──────────────────────────────────────────────────────────────

output "quickstart" {
  description = "Quick reference after deployment"
  value = <<-EOT

    ============================================================
      Drift Playground — Deployed!
    ============================================================

    SA Email:      ${google_service_account.drift_sa.email}
    State Bucket:  ${google_storage_bucket.tf_state.name}
    Alert Email:   ${var.alert_email}
    Scheduler:     ${google_cloud_scheduler_job.drift_check_cron.name} (every 6h)
    Build Trigger: ${google_cloudbuild_trigger.drift_check.name}

    --- Test drift detection manually ---

    1. Go to GCP Console > IAM and add a role to drift-playground-sa
    2. Run: terraform plan -detailed-exitcode
       (exit code 2 = drift detected)
    3. Or trigger the Cloud Build job:
       gcloud builds triggers run drift-check \
         --region=${var.region} --branch=${var.repo_branch}

    --- View alerts ---

    Cloud Build logs:
      https://console.cloud.google.com/cloud-build/builds?project=${var.project_id}

    Monitoring alerts:
      https://console.cloud.google.com/monitoring/alerting?project=${var.project_id}

    ============================================================
  EOT
}
