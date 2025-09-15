resource "google_artifact_registry_repository" "bookings" {
  location      = "europe-west1"
  repository_id = "cloud-run-source-deploy"
  description   = "Cloud Run Source Deployments"
  format        = "DOCKER"
}

resource "google_cloudbuild_trigger" "bookings" {
  name        = "bookings-trigger"
  description = "Build and deploy to Cloud Run service bookings on push to main"
  location    = "global"
  github {
    owner = "mark-church"
    name  = "bookings"
    push {
      branch = "^main$"
    }
  }

  build {
    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "build",
        "-t",
        "${google_artifact_registry_repository.bookings.location}-docker.pkg.dev/$PROJECT_ID/${google_artifact_registry_repository.bookings.repository_id}/bookings:$COMMIT_SHA",
        "."
      ]
    }

    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "push",
        "${google_artifact_registry_repository.bookings.location}-docker.pkg.dev/$PROJECT_ID/${google_artifact_registry_repository.bookings.repository_id}/bookings:$COMMIT_SHA"
      ]
    }

    step {
      name = "gcr.io/google.com/cloudsdktool/cloud-sdk"
      entrypoint = "gcloud"
      args = [
        "run",
        "deploy",
        "bookings",
        "--image",
        "${google_artifact_registry_repository.bookings.location}-docker.pkg.dev/$PROJECT_ID/${google_artifact_registry_repository.bookings.repository_id}/bookings:$COMMIT_SHA",
        "--region",
        "europe-west1",
        "--platform",
        "managed",
        "--allow-unauthenticated"
      ]
    }
  }
}

resource "google_cloud_run_v2_service" "bookings" {
  name     = "bookings"
  location = "europe-west1"

  template {
    containers {
      image = "${google_artifact_registry_repository.bookings.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.bookings.repository_id}/bookings:latest"
      ports {
        container_port = 8000
      }
    }
  }
}
