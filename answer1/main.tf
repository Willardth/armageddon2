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
  credentials = "love-terraform-project-f30ae0f1b12a.json"

}

resource "google_storage_bucket" "static-site" {
  name          = "i-love-terraform"
  storage_class = "STANDARD"
  location      = "us-central1"
  uniform_bucket_level_access = false
  
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

resource "google_storage_bucket_access_control" "public_rule" {
  bucket = google_storage_bucket.static-site.name
  role   = "READER"
  entity = "allUsers"
}

resource "google_storage_object_access_control" "public_rule" {
  object = google_storage_bucket_object.index.output_name
  bucket = google_storage_bucket.static-site.name
  role   = "READER"
  entity = "allUsers"
}

output "website_url" {
  value = "https://storage.googleapis.com/${google_storage_bucket.static-site.name}/index.html"
}