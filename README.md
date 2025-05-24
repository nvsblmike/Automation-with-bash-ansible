# Automated AMI Creation with Terraform & Ansible + CloudWatch Monitoring

![AWS Infrastructure Diagram]()

A comprehensive guide to creating custom Amazon Machine Images (AMIs) with infrastructure-as-code and configuration management.

Hi, this is a tutorial on how to create an Amazon Machine Image using Ansible. We’d also be setting up cloudWatch metrics for monitoring. 
It is an excerpt from the tutorial made by NotHarshaa https://github.com/NotHarshhaa/DevOps-Projects/tree/master/DevOps-Project-01
He has done a fantastic job of delivering top notch project ideas and breaking them down.

## 📋 Prerequisites

- AWS Free Tier Account
- GitHub Account & Repository
- IDE (VS Code Recommended)
- Basic understanding of:
  - Terraform (Infrastructure as Code)
  - Ansible (Configuration Management)
  - AWS EC2 & CloudWatch
 
What I just do here is to show my own step by step implementation of creating an AMI.
There are some prerequisites that we need to ensure are set before we proceed:
You must have an AWS free tier account.
Github account and repo. You can fork this project.
IDE - like visual studio code

Stage 1:
There are some things we need to know before we create our AMI.
What is a global AMI: A global AMI is an Amazon Machine Image that is available across multiple AWS region, allowing consistent EC2 instance launches anywhere.

The first thing is for you to get an EC2 instance. You could go through the route of provisioning it via the console or using IaC to provision the application.
For this project, I made use of Terraform.

Steps:
1. Create a new folder in your local directory 
![image](https://github.com/user-attachments/assets/12dfb097-bf03-4d67-8811-93cd910bf6d7)

In this case, I created a folder in an existing directory. I created the folder javaapp.
Enter into this folder.
In this folder, you can enter code . to open that directory in Visual Studio Code.
2. Create two files named main.tf and variables.tf like below:
![image](https://github.com/user-attachments/assets/1bfe5bc6-ecc8-414c-bf4c-bf19b771ba31)


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
