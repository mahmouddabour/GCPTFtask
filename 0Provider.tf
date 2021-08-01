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