##──────────────────────────────────────────────────────────────
## Remote State Bucket
##
## This bucket stores your Terraform state file remotely in GCS.
## It's the first thing to create — run `terraform apply` with
## the backend block in main.tf still commented out, then
## uncomment and run `terraform init` to migrate state.
##──────────────────────────────────────────────────────────────

resource "google_storage_bucket" "tf_state" {
  name     = "${var.project_id}-tf-state"
  location = var.region
  project  = var.project_id

  # Prevent accidental deletion of the state bucket
  force_destroy = false

  # Keep 5 versions of the state file so you can recover
  versioning {
    enabled = true
  }

  # Clean up old state versions after 30 days
  lifecycle_rule {
    condition {
      num_newer_versions = 5
    }
    action {
      type = "Delete"
    }
  }

  labels = local.base_labels

  uniform_bucket_level_access = true
}

output "state_bucket_name" {
  description = "Name of the GCS bucket holding Terraform state"
  value       = google_storage_bucket.tf_state.name
}
