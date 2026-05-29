#!/bin/bash

sudo apt update
sudo apt install default-jdk
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt-get update
sudo apt-get install jenkins
sudo systemctl enable jenkins
sudo systemctl enable jenkins
sudo systemctl start  jenkins
sudo systemctl status   jenkins

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data source to get the latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group
resource "aws_security_group" "compute_sg" {
  name        = "${var.instance_name}-sg"
  description = "Security group for ${var.instance_name}"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.instance_name}-sg"
  }
}

# EC2 Instance
resource "aws_instance" "compute" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.compute_sg.id]
  associate_public_ip_address = true

  user_data = base64encode(file("${path.module}/user_data.sh"))

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true
  }

  monitoring = true

  tags = {
    Name = var.instance_name
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
}

# Elastic IP
resource "aws_eip" "compute" {
  instance = aws_instance.compute.id
  domain   = "vpc"

  tags = {
    Name = "${var.instance_name}-eip"
  }

  depends_on = [aws_instance.compute]
}
# backend.tf
terraform {
    backend "s3" {
        bucket         = "your-s3-bucket-name"
        key            = "terraform/state"
        region         = "ca-central-1"
    }
}

# variables.tf
variable "aws_region" {
    default = "ca-central-1"
}

variable "instance_name" {
    description = "Name of the instance"
    type        = string
}

variable "instance_type" {
    description = "EC2 instance type"
    default     = "t2.micro"
}

variable "vpc_id" {
    description = "VPC ID"
    type        = string
}

variable "subnet_id" {
    description = "Subnet ID"
    type        = string
}

variable "allowed_ssh_cidr" {
    description = "CIDR block for allowed SSH access"
    default     = ["0.0.0.0/0"]
}

variable "key_name" {
    description = "SSH key name"
    default     = "sept23.pem"
}

variable "root_volume_size" {
    description = "Root volume size in GB"
    default     = 20
}

# user_data.sh
#!/bin/bash
# Install Docker
sudo apt-get update
sudo apt-get install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker

# Run Jenkins installation script
bash /path/to/jenkins-install.sh