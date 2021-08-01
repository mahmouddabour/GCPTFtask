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
    ports    = ["80"]
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

# resource "google_service_account" "default" {
#   account_id   = "hiii"
#   display_name = "Service Account"
# }

output "ip" {
  value = "${google_compute_instance.default.network_interface.0.access_config.0.nat_ip}"
}