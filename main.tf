resource "google_compute_network" "vpc_network" {
  name = "vpc-network"
}

resource "google_compute_subnetwork" "network-with-private-secondary-ip-ranges" {
  name          = "test-subnetwork"
  ip_cidr_range = "10.2.0.0/16"
  region        = "us-central1"
  network       = google_compute_network.vpc_network.id
  
}
resource "google_compute_subnetwork" "network-with-PUBLIC-secondary-ip-ranges" {
  name          = "test-subnetwork"
  ip_cidr_range = "10.3.0.0/16"
  region        = "europe-west1"
  network       = google_compute_network.vpc_network.id
  
}



resource "random_id" "instance_id" {
  byte_length = 8
}

resource "google_compute_instance" "default" {
  name         = "vmpublic-${random_id.instance_id.hex}"
  machine_type = "f1-micro"
  zone         = "europe-west1-b"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
      size = 10
      type = "pd-ssd"
    }
  }

  metadata_startup_script = "sudo apt-get update && sudo apt-get install apache2 -y && echo '<!doctype html><html><body><h1>Hello from Terraform on Google Cloud! ya Dabour</h1></body></html>' | sudo tee /var/www/html/index.html"

  network_interface {
    network = "vpc-network"
subnetwork = google_compute_subnetwork.network-with-PUBLIC-secondary-ip-ranges.id
    access_config {
      // Include this section to give the VM an external ip address
    }
  }

  // Apply the firewall rule to allow external IPs to access this instance
  tags = ["http-server"]
}


resource "google_compute_instance" "default2" {
  name         = "vmprivate-${random_id.instance_id.hex}"
  machine_type = "f1-micro"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
      size = 10
      type = "pd-ssd"
    }
  }

  metadata_startup_script = "sudo apt-get update && sudo apt-get install apache2 -y && echo '<!doctype html><html><body><h1>Hello from Terraform on Google Cloud!</h1></body></html>' | sudo tee /var/www/html/index.html"

  network_interface {
    network = "vpc-network"
    subnetwork = google_compute_subnetwork.network-with-private-secondary-ip-ranges.id
  }

  // Apply the firewall rule to allow external IPs to access this instance
  tags = ["http-server"]
}



resource "google_compute_firewall" "http-server" {
  name    = "default-allow-http"
  network = "vpc-network"

  allow {
    protocol = "tcp"
    ports    = ["80","8080"]
  }

  // Allow traffic from everywhere to instances with an http-server tag
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server"]
}


resource "google_compute_router" "router" {
  name    = "my-router"
  region  = google_compute_subnetwork.network-with-private-secondary-ip-ranges.region
  network = google_compute_network.vpc_network.id


}

resource "google_compute_router_nat" "nat" {
  name                               = "my-router-nat"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_service_account" "default" {
  account_id   = "dabournti"
  display_name = "Service Account"
}


resource "google_container_cluster" "primary" {
  name     = "my-gke-cluster"
  location = "us-central1"

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1
}

resource "google_container_node_pool" "primary_preemptible_nodes" {
  name       = "my-node-pool"
  location   = "us-central1"
  cluster    = google_container_cluster.primary.name
  node_count = 1

  node_config {
    preemptible  = true
    machine_type = "e2-medium"

    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.default.email
    oauth_scopes    = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

resource "google_storage_bucket" "static-site" {
  name          = "dabourntiimagestorecom"
  location      = "europe-west2"
}

resource "google_bigquery_dataset" "dataset" {
  dataset_id                  = "example_dataset"
  friendly_name               = "test"
  description                 = "This is a test description"
  location                    = "europe-west2"
  default_table_expiration_ms = 3600000

  labels = {
    env = "default"
  }

  access {
    role          = "OWNER"
    user_by_email = google_service_account.bqowner.email
  }

  access {
    role   = "READER"
    domain = "hashicorp.com"
  }
}

resource "google_service_account" "bqowner" {
  account_id = "dabournti2"
}

data "google_iam_policy" "admin" {
  binding {
    role = "roles/compute.osLogin"
    members =["serviceAccount:dabournti@dabournti.iam.gserviceaccount.com",]
  }
}

resource "google_compute_instance_iam_policy" "policy" {
  project = google_compute_instance.default.project
  zone = google_compute_instance.default.zone
  instance_name = google_compute_instance.default.name
  policy_data = data.google_iam_policy.admin.policy_data
}


output "ip" {
  value = "${google_compute_instance.default.network_interface.0.access_config.0.nat_ip}"
}