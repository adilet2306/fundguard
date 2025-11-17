provider "google" {
  project     = var.project
  region      = "us-central1"
  credentials = file("service.json")
}

resource "google_compute_firewall" "allow_all" {
  name    = "allow-all"
  project = var.project
  network = "default"
  direction = "INGRESS"
  priority  = 1000

  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["30092"]
  }
}

resource "google_project_service" "my_service" {
  project                    = var.project
  service                    = "compute.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = false
}

resource "google_compute_instance" "kubeadm" {
  depends_on = [google_project_service.my_service]

  name         = "kubeadm"
  machine_type = "e2-medium"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  metadata = {
    ssh-keys = <<EOT
    ${var.user}:${file("~/.ssh/id_rsa.pub")}
    EOT
  }

    provisioner "file" {
    source      = "elastic.yaml"
    destination = "/tmp/elastic.yaml"
    connection {
      type        = "ssh"
      user        = var.user
      private_key = file("~/.ssh/id_rsa")
      host        = self.network_interface[0].access_config[0].nat_ip
    }
  }


  provisioner "remote-exec" {
    inline = [
      "echo '$nrconf{restart} = \"a\";' | sudo tee /etc/needrestart/needrestart.conf",
      "sudo bash -lc 'export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a; apt-get -yq -o Dpkg::Use-Pty=0 update'",
      "sudo bash -lc 'export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a; apt-get -yq -o Dpkg::Use-Pty=0 upgrade'",
      "sudo swapoff -a",
      "sudo sed -i '/ swap / s/^/#/' /etc/fstab",
      "echo 'overlay\nbr_netfilter' | sudo tee /etc/modules-load.d/containerd.conf",
      "sudo modprobe overlay",
      "sudo modprobe br_netfilter",
      "echo 'net.bridge.bridge-nf-call-ip6tables = 1' | sudo tee -a /etc/sysctl.d/kubernetes.conf",
      "echo 'net.bridge.bridge-nf-call-iptables = 1' | sudo tee -a /etc/sysctl.d/kubernetes.conf",
      "echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.d/kubernetes.conf",
      "sudo sysctl --system",
      "sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/docker.gpg",
      "sudo add-apt-repository -y \"deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\"",
      "sudo apt update",
      "sudo apt install -y containerd.io",
      "containerd config default | sudo tee /etc/containerd/config.toml",
      "sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml",
      "sudo systemctl restart containerd && sudo systemctl enable containerd",
      "sudo mkdir -p /etc/apt/keyrings",
      "curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg",
      "echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list",
      "sudo apt update",
      "sudo apt install -y kubelet kubeadm kubectl",
      "sudo apt-mark hold kubelet kubeadm kubectl",
      "sudo kubeadm init --pod-network-cidr=192.168.0.0/16",
      "mkdir -p $HOME/.kube",
      "sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config",
      "sudo chown $(id -u):$(id -g) $HOME/.kube/config",
      "kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml",
      "kubectl taint node kubeadm node-role.kubernetes.io/control-plane:NoSchedule-",
      "kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml",
      "kubectl patch deployment metrics-server -n kube-system --type='json' -p='[{\"op\": \"add\", \"path\": \"/spec/template/spec/containers/0/args/-\", \"value\": \"--kubelet-insecure-tls\"}, {\"op\": \"add\", \"path\": \"/spec/template/spec/containers/0/args/-\", \"value\": \"--kubelet-preferred-address-types=InternalIP\"}]'",
      "echo 'alias k=kubectl' >> ~/.bashrc",
      "kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml",
      "kubectl patch storageclass local-path -p '{\"metadata\":{\"annotations\":{\"storageclass.kubernetes.io/is-default-class\":\"true\"}}}'",
      "kubectl create -f https://download.elastic.co/downloads/eck/3.2.0/crds.yaml",
      "kubectl apply -f https://download.elastic.co/downloads/eck/3.2.0/operator.yaml",
      "sleep 30",
      "kubectl apply -f /tmp/elastic.yaml",    
    ]

    connection {
      type        = "ssh"
      user        = var.user
      private_key = file("~/.ssh/id_rsa")
      host        = self.network_interface[0].access_config[0].nat_ip
    }
  }
}