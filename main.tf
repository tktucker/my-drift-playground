##──────────────────────────────────────────────────────────────
## Drift Playground — Main Configuration
##
## Service Account + IAM bindings as drift targets, plus an
## automated drift detector that emails you when drift is found.
##
## Cost: effectively $0 (all resources within free tier)
##──────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  # Uncomment after creating the state bucket (see backend.tf)
  # backend "gcs" {
  #   bucket = "YOUR_PROJECT_ID-tf-state"
  #   prefix = "drift-playground"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

##──────────────────────────────────────────────────────────────
## Enable required APIs
##──────────────────────────────────────────────────────────────

resource "google_project_service" "apis" {
  for_each = toset([
    "cloudbuild.googleapis.com",
    "cloudscheduler.googleapis.com",
    "secretmanager.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "iam.googleapis.com",
    "cloudfunctions.googleapis.com",
    "run.googleapis.com",
    "eventarc.googleapis.com",
    "artifactregistry.googleapis.com",
  ])

  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}

##──────────────────────────────────────────────────────────────
## Locals — shared labels & naming
##──────────────────────────────────────────────────────────────

locals {
  base_labels = {
    environment = var.environment
    managed_by  = "terraform"
    project     = "drift-playground"
  }
}
