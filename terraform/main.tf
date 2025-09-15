# Terraform configuration to reproduce GKE disk space issue
# This reproduces a case where a pod writes to a local volume and fills up the disk, crashing the node
# Configure Google Cloud provider
provider "google" {
  project = var.project
  region  = var.region
  zone    = var.zone
}
# Configure Kubernetes provider - will be configured after cluster creation
provider "kubernetes" {
  host                   = "https://${google_container_cluster.disk_fill_cluster.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.disk_fill_cluster.master_auth[0].cluster_ca_certificate)
}
# Get current Google Cloud configuration
data "google_client_config" "default" {}
# VPC Network for GKE cluster
resource "google_compute_network" "vpc" {
  name                    = "${var.environment_prefix}-vpc"
  auto_create_subnetworks = false
}
# Subnet for GKE cluster
resource "google_compute_subnetwork" "subnet" {
  name          = "${var.environment_prefix}-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
}
# GKE Cluster with 3 nodes
resource "google_container_cluster" "disk_fill_cluster" {
  name     = "${var.environment_prefix}-cluster"
  location = var.zone
  # Remove default node pool
  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = false
  # Network configuration
  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name
  # Master authorized networks
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "All"
    }
  }
  # Node pool configuration
  node_config {
    machine_type = "e2-standard-2"
    disk_size_gb = 20  # Smaller disk to make it easier to fill
    # OAuth scopes
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_only"
    ]
    metadata = {
      disable-legacy-endpoints = "true"
    }
    labels = {
      environment = var.environment_prefix
    }
    tags = ["gke-node", "${var.environment_prefix}-node"]
  }
  # Private cluster configuration
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }
  # IP allocation policy
  ip_allocation_policy {
    cluster_ipv4_cidr_block  = "/16"
    services_ipv4_cidr_block = "/22"
  }
  # Configure kubectl after cluster creation
  provisioner "local-exec" {
    command = "gcloud container clusters get-credentials ${self.name} --zone ${var.zone} --project ${var.project}"
  }
}
# Node pool with 3 nodes
resource "google_container_node_pool" "primary_nodes" {
  name       = "${var.environment_prefix}-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.disk_fill_cluster.name
  node_count = 3
  node_config {
    machine_type = "e2-standard-2"
    disk_size_gb = 20  # Smaller disk to make it easier to fill
    # OAuth scopes
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_only"
    ]
    metadata = {
      disable-legacy-endpoints = "true"
    }
    labels = {
      environment = var.environment_prefix
    }
    tags = ["gke-node", "${var.environment_prefix}-node"]
  }
  # Autoscaling configuration
  autoscaling {
    min_node_count = 1
    max_node_count = 5
  }
  # Management configuration for node replacement
  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

resource "null_resource" "apply_k8s_manifests" {
  depends_on = [google_container_node_pool.primary_nodes]

  provisioner "local-exec" {
    command = "kubectl apply -f k8s.yaml"
  }
}