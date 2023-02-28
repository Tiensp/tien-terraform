terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "2.7.0"
    }
  }
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
    docker-compose up -d

    # INSTALL NGINX
    sudo apt-get install -y nginx

    # COPY NGINX CONFIGURATION FILE
    sudo cp ./nginx.conf /etc/nginx/sites-available/tien-kafka
    sudo ln -s /etc/nginx/sites-available/tien-kafka /etc/nginx/sites-enabled/

    # RESTART NGINX
    sudo systemctl restart nginx

    # START DOCKER COMPOSE
    docker-compose up -d

  EOF
}

resource "digitalocean_ssh_key" "default-ssh" {
  name       = "tien-ssh-1"
  public_key = file(".ssh/id_rsa.pub")
}

provider "digitalocean" {
  token = var.do_token
}
