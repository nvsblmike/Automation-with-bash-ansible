variable "aws_region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "ssh_key_name" {
  description = "terraform-proj-ssh-key"
  type        = string
  default = "terraform-proj-ssh-key"
}

variable "environment" {
  description = "Deployment environment"
  default     = "prod"
}

variable "ubuntu_version" {
  description = "Ubuntu version codename"
  default     = "jammy"  # 22.04 LTS
}

variable "docker_version" {
  description = "Docker version to install"
  default     = "5:24.0.7-1~ubuntu.22.04~jammy"
}

