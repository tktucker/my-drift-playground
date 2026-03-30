##──────────────────────────────────────────────────────────────
## Variables — Drift Playground
##──────────────────────────────────────────────────────────────

variable "project_id" {
  description = "GCP project ID (not project name)"
  type        = string
}

variable "region" {
  description = "Default GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Default GCP zone (used by some resources)"
  type        = string
  default     = "us-central1-a"
}

variable "environment" {
  description = "Environment label (dev / staging / prod)"
  type        = string
  default     = "dev"
}

##──────────────────────────────────────────────────────────────
## Drift Detector Variables
##──────────────────────────────────────────────────────────────

variable "alert_email" {
  description = "Email address to receive drift alert notifications"
  type        = string
  default     = "tktucker@gmail.com"
}

variable "repo_uri" {
  description = "GitHub repository URI for Cloud Build (e.g., https://github.com/you/repo)"
  type        = string
}

variable "repo_branch" {
  description = "Git branch to use for drift detection builds"
  type        = string
  default     = "main"
}
