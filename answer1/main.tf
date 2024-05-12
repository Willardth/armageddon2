terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "5.28.0"
    }
  }
}

provider "google" {
  # Configuration options

  project = "love-terraform-project"
  region = "us-central1"
  zone = "us-central1-b"
  credentials = "love-terraform-project-cac637d5eadc.json"

}

resource "google_storage_bucket" "static-site" {
  name          = "i-love-terraform"
  storage_class = "STANDARD"
  location      = "us-central1"
  uniform_bucket_level_access = true

  website {
    main_page_suffix = "index.html"
    not_found_page   = "404.html"
  }
}

resource "google_storage_bucket_object" "index" {
  name   = "index.html"
  bucket = google_storage_bucket.static-site.name
  source = "index.html"
  content_type = "text/html"
}