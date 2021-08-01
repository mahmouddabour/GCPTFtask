provider "google" {
  project     = "dabournti"
  region      = "us-central1"
}

terraform {
  required_providers {
    random = {
      source = "hashicorp/random"
      version = "3.1.0"
    }
  }
}

provider "random" {
  # Configuration options
}

resource "google_project_service" "project" {
  project = "dabournti"
  service = "compute.googleapis.com"

  timeouts {
    create = "30m"
    update = "40m"
  }

  disable_dependent_services = true
}