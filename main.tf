terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "2.7.0"
    }
  }
}

data "digitalocean_droplet" "tien-terraform" {
  name = "tien-kafka"
}

# Lưu trữ địa chỉ IP của máy chủ vào một biến
locals {
  server_ip = data.digitalocean_droplet.tien-terraform.ipv4_address
}

resource "digitalocean_droplet" "tien-terraform" {
  image     = "ubuntu-18-04-x64"
  name      = "tien-kafka"
  region    = "sgp1"
  size      = "s-1vcpu-1gb"
  ssh_keys  = [digitalocean_ssh_key.default-ssh.fingerprint]
  user_data = <<-EOF
		#!/bin/bash
    # CREATE SWAP
    sudo fallocate -l 4G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    sudo cat /etc/fstab >> /swapfile swap swap defaults 0 0

    # INSTALL DOCKER
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io

    # ADD DOCKER USER AS ROOT USER
    sudo groupadd docker
    sudo usermod -aG docker $USER
    newgrp docker
    sudo chmod 666 /var/run/docker.sock

    # INSTALL DOCKER COMPOSE
    sudo curl -L "https://github.com/docker/compose/releases/download/1.29.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

    # SET MAX SESSION FOR SSH VPS
    echo "MaxSessions 50" | sudo tee -a /etc/ssh/sshd_config > /dev/null
    sudo systemctl restart sshd

    # INSTALL GIT
    sudo apt-get update
    sudo apt-get install git
    git clone https://Tiensp:"${var.github_token}"@github.com/Tiensp/tien-terraform.git
    cd tien-terraform

    # START DOCKER COMPOSE
    docker-compose up -d

    # INSTALL NGINX
    sudo apt-get install -y nginx

    # CONFIGURE NGINX
    sudo tee /etc/nginx/sites-available/default << EOT
      server {
          listen 80 default_server;
          listen [::]:80 default_server;
          server_name _;
          location / {
              proxy_pass http://${local.server_ip}:8080;
              proxy_set_header Host \$host;
              proxy_set_header X-Real-IP \$remote_addr;
              proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
          }
      }
    EOT

    # RESTART NGINX
    sudo systemctl restart nginx

    # CONFIGURE FIREWALL
    sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
    sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
    sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    sudo iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED -j ACCEPT
    sudo iptables -A INPUT -j DROP

    # SAVE FIREWALL RULES
    sudo sh -c "iptables-save > /etc/iptables.rules"

    # ENABLE FIREWALL AT BOOT TIME
    sudo apt-get install -y iptables-persistent
    sudo systemctl enable netfilter-persistent
    sudo systemctl start netfilter-persistent

  EOF
}
resource "digitalocean_ssh_key" "default-ssh" {
  name       = "tien-ssh-1"
  public_key = file(".ssh/id_rsa.pub")
}

provider "digitalocean" {
  token = var.do_token
}


