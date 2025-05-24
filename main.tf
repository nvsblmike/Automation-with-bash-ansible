# main.tf
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Environment   = "Production"
      Terraform     = "true"
      Project       = "CI/CD Pipeline"
      CostCenter    = "DevOps"
    }
  }
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"
  
  name   = "main-vpc"
  cidr   = "10.0.0.0/16"

  azs             = ["${var.aws_region}a"]
  public_subnets  = ["10.0.1.0/24"]
  private_subnets = ["10.0.2.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = true

  enable_dns_support = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "NetworkTier" = "Public"
  }

  private_subnet_tags = {
    "NetworkTier" = "Private"
  }
}

# SSH Key Management
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "secret-key-${var.environment}"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

resource "local_file" "private_key" {
  content  = tls_private_key.ssh_key.private_key_pem
  filename = "${path.module}/.ssh/secret-private-key.pem"
  file_permission = "0600"
}

resource "aws_security_group" "baseami_apache_sg" {
  name        = "baseami-apache-sg"
  description = "Base AMI EC2 Apache security group"
  vpc_id = module.vpc.vpc_id
  
  ingress {
    description = "SSH from trusted IPs"
    from_port   = 22
    to_port     = 22
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
    Role = "cloudwatch-apache"
  }
}

resource "aws_instance" "baseami-apache-ec2" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.baseami_apache_sg.id]
  key_name               = aws_key_pair.generated_key.key_name

  monitoring             = true
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/ansible-controller-setup.sh.tpl", {
    private_key_content = tls_private_key.ssh_key.private_key_pem
    ansible_user        = "ubuntu"
    SSH_DIR             = "/home/ubuntu/.ssh"
  })

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name = "baseAMIApache"
  }
}

resource "aws_security_group" "baseami_sg" {
  name        = "baseami-sg"
  description = "Base AMI EC2 security group"
  vpc_id = module.vpc.vpc_id
  
  ingress {
    description = "SSH from trusted IPs"
    from_port   = 22
    to_port     = 22
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
    Role = "cloudwatch"
  }
}

resource "aws_instance" "baseami-ec2" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.baseami_sg.id]
  key_name               = aws_key_pair.generated_key.key_name

  monitoring             = true
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/ansible-controller-setup.sh.tpl", {
    private_key_content = tls_private_key.ssh_key.private_key_pem
    ansible_user        = "ubuntu"
    SSH_DIR             = "/home/ubuntu/.ssh"
  })

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name = "baseAMI"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's AWS account ID

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}