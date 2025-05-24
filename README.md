# Automated AMI Creation with Terraform & Ansible + CloudWatch Monitoring

![AWS Infrastructure Diagram](https://via.placeholder.com/800x400.png?text=Architecture+Diagram)

A comprehensive guide to creating custom Amazon Machine Images (AMIs) with infrastructure-as-code and configuration management.

## 📋 Prerequisites

- AWS Free Tier Account
- GitHub Account & Repository
- IDE (VS Code Recommended)
- Basic understanding of:
  - Terraform (Infrastructure as Code)
  - Ansible (Configuration Management)
  - AWS EC2 & CloudWatch

## 🛠️ Infrastructure Setup with Terraform

### File Structure

ami-builder/
├── main.tf
├── variables.tf
├── .gitignore
└── ansible-controller-setup.sh.tpl


### 1. Terraform Configuration

`main.tf` - Core infrastructure definition:
```terraform
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
      Environment = "Production"
      Terraform   = "true"
      Project     = "CI/CD Pipeline"
      CostCenter  = "DevOps"
    }
  }
}
```

# VPC Module Configuration
```terraform
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"
  
  name = "main-vpc"
  cidr = "10.0.0.0/16"
  
  azs             = ["${var.aws_region}a"]
  public_subnets  = ["10.0.1.0/24"]
  private_subnets = ["10.0.2.0/24"]
  
  enable_nat_gateway     = true
  single_nat_gateway     = true
  enable_dns_support     = true
  enable_dns_hostnames   = true
}
```

# EC2 Instance Configuration
```terraform
resource "aws_instance" "baseami-ec2" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  subnet_id     = module.vpc.public_subnets[0]
  
  user_data = templatefile("${path.module}/ansible-controller-setup.sh.tpl", {
    private_key_content = tls_private_key.ssh_key.private_key_pem
    ansible_user        = "ubuntu"
    SSH_DIR             = "/home/ubuntu/.ssh"
  })

  tags = {
    Name = "baseAMI"
  }
}
```

# 2. Variable Definitions (variables.tf)

variable "aws_region" {
  description = "AWS deployment region"
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment"
  default     = "prod"
}

3. Initialize & Deploy

terraform init
terraform plan
terraform apply