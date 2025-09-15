variable "project" {
  description = "Google Cloud project ID"
  type        = string
  default     = "mark-church-project"
}

variable "region" {
  description = "Google Cloud region"
  type        = string
  default = "us-central1"
}

variable "zone" {
  description = "Google Cloud zone"
  type        = string
  default = "us-central1-a"
}

variable "environment_prefix" {
  description = "Environment prefix for resource names"
  type        = string
  default     = "gke-013"
}