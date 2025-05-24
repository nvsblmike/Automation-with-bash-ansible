# AMI Creation with Terraform & Ansible + CloudWatch Monitoring

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
- You must have an AWS free tier account.
- Github account and repo. You can fork this project.
- An IDE, like visual studio code.

# Stage 1:
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

javaapp/
├── main.tf
├── variables.tf
├── .gitignore
└── ansible-controller-setup.sh.tpl


### 1. Terraform Configuration

3. Populate main.tf with this:
```
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
```
# Explanation of main.tf
✅ 1. Providers & Requirements
Requires Terraform ≥ 1.5.0.

Uses the AWS provider (~> 5.0).

✅ 2. AWS Provider Configuration
Region is dynamic (via var.aws_region).

Tags all resources with Environment, Terraform, Project, and CostCenter.

✅ 3. VPC Module
Creates a custom VPC with:
One public and one private subnet (in a single AZ).

NAT Gateway (single).

DNS support & hostnames.

Subnet tagging for public/private network tiers.

✅ 4. SSH Key Management
Generates an RSA 4096-bit key pair.

Uploads the public key to AWS EC2 (as a Key Pair).

Saves the private key locally to .ssh/secret-private-key.pem.

✅ 5. Security Group
Creates a Security Group for the EC2 instance:
Allows SSH (port 22) from anywhere.

Allows all outbound traffic.

Tagged with Role = cloudwatch.

✅ 6. EC2 Instance
Launches a t2.micro instance:
Uses latest Ubuntu 22.04 AMI (Jammy Jellyfish).

Placed in the public subnet.

Uses the created SSH key pair and security group.

CloudWatch monitoring enabled.

Executes a startup script (ansible-controller-setup.sh.tpl) using user_data.

30 GB gp3 volume.

Tagged as Name = baseAMI.


✅ 7. Data Source
Fetches the most recent official Ubuntu 22.04 AMI from Canonical.


4. Populate variables.tf with this:
```
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



```
# Explanation of the variables.tf file
aws_region
Description: The AWS region where all resources will be deployed.


Default: "us-east-1" (N. Virginia).

✅ ssh_key_name
Description: Name of the SSH key to be used for EC2 instances.

Type: string

Default: "terraform-proj-ssh-key"

✅ environment
Description: Used to tag or configure resources based on environment (e.g., dev, prod).

Default: "prod"

✅ ubuntu_version
Description: The codename for the Ubuntu version to use.

Default: "jammy" → Ubuntu 22.04 LTS

✅ docker_version
Description: Specific Docker version to be installed on EC2 instances.

Default: "5:24.0.7-1~ubuntu.22.04~jammy" → This ensures version 24.0.7 compatible with Ubuntu 22.04


5. Add a .gitignore file to avoid pushing unwanted files. Mine has  the following content:
```
# These are some examples of commonly ignored file patterns.
# You should customize this list as applicable to your project.
# Learn more about .gitignore:
#     https://www.atlassian.com/git/tutorials/saving-changes/gitignore


# Node artifact files
node_modules/
dist/


# Compiled Java class files
*.class


# Compiled Python bytecode
*.py[cod]


# Log files
*.log


# Package files
*.jar


# Maven
target/
dist/


# JetBrains IDE
.idea/


# Unit test reports
TEST*.xml


# Generated by MacOS
.DS_Store


# Generated by Windows
Thumbs.db


# Applications
*.app
*.exe
*.war


# Large media files
*.mp4
*.tiff
*.avi
*.flv
*.mov
*.wmv
./prerequisites.sh


.ssh
# Ignore Terraform state files
terraform.tfstate
terraform.tfstate.backup


# Ignore Terraform cache and logs
.terraform/
.terraform.lock.hcl
crash.log


# Ignore Terraform variable files that may contain secrets
*.tfvars
*.tfvars.json


node_modules


.ssh/
*.pem
*.key


prerequisites.sh
# Ignore VS Code settings
.vscode/


# Ignore system files
.DS_Store
Thumbs.db


vpn-cert/
```
6. Next you should run the following command to initialize the terraform project:

```
– terraform init
```
![image](https://github.com/user-attachments/assets/ad309bf0-86e7-42a9-a988-f7fa6fe0f13a)
You should see something like the following in your project when done:
![image](https://github.com/user-attachments/assets/0c9d5b1f-fee8-46c2-b2e7-7b048d8aad0b)


It might take sometime but wait till it’s done.

The next step is to deploy the infrastructure. But before that we want to create a script that would install ansible inside our EC2 instance. It is installed using terraform. In the code you copied into main.tf, you’d see the place where this happens:
```
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
```

The content of ansible-controller-setup.sh.tpl is:
```
#!/bin/bash
# System setup
sudo apt-get update -y
sudo apt-get install -y software-properties-common ansible python3-pip
sudo pip3 install boto3


# Ensure user exists (idempotent)
sudo id -u ${ansible_user} &>/dev/null || sudo useradd ${ansible_user}


# SSH configuration using Terraform variables
SSH_DIR="/home/${ansible_user}/.ssh"
sudo mkdir -p ${SSH_DIR}
sudo tee ${SSH_DIR}/secret-key.pem >/dev/null <<EOF
${private_key_content}
EOF


# Strict permissions
sudo chmod 700 ${SSH_DIR}
sudo chmod 600 ${SSH_DIR}/secret-key.pem
sudo chown -R ${ansible_user}:${ansible_user} ${SSH_DIR}


# Debug output
echo "Key deployed at: $(date)" | sudo tee ${SSH_DIR}/deployment.log
```

Using:
```
– terraform plan
```
Let’s check what we want to provision:

It’s up to 20 resources we’d be adding as seen below:
![image](https://github.com/user-attachments/assets/7a46a7cb-0423-4079-bc48-7443a80047cd)


7. Before deployment, make sure you configure aws account using an IAM user. You can set up a user with AdministratorAccess as policy in the console. Get the Access key and the secret access key.
Run:
```
– aws configure
```
Add the access key and the secret access key including your region.

8. After that, run:
```
– terraform apply
```
Type out yes
![image](https://github.com/user-attachments/assets/98521f03-dc9e-4273-b0ff-d331ab5295ae)


When done you should see this:
![image](https://github.com/user-attachments/assets/1efb4ae9-9ad8-4d26-b7b1-2c51f0d0f64c)


9. The next thing to do is check the EC2 instance in your account using the command:
```
– aws ec2 describe-instances --query "Reservations[*].Instances[*].[InstanceId, PublicIpAddress, PrivateIpAddress, Tags[?Key=='Name'].Value | [0]]" --output table
```

You can only run this when you’ve configured aws CLI locally.
![image](https://github.com/user-attachments/assets/3de50291-a1ba-4176-afdd-ca8018ec0a26)


10. Up next is to install the following on our EC2 instance:
- install AWS CLI
- Install Cloudwatch agent
- Install AWS Systems Manager (SSM) Agent
- Install nginx and configure cloudwatch metrics

We're going to use Ansible to install all of these.

Firstly create a folder called ansible
Create a file called hosts.ini inside this ansible folder.
Add the following content into the hosts.ini file:
```
[Cloudwatch]
localhost ansible_connection=local
```
![image](https://github.com/user-attachments/assets/2d275a21-630c-4c40-8c1f-8e70033ef4be)

Why the hosts.ini file is specified so is because we’d be installing the softwares in the EC2 where we installed ansible.

11. Up next is to get the ansible playbook for the installation of the softwares mentioned above.

Create three files:
Configure-aws-cli.yml
Configure-monitoring-agents.yml
Configure-nginx-and-metrics.yml

All in the ansible folder


12. Now we need to install them in the EC2 instance we spun up.
– using the command to get our EC2 instance:
```
aws ec2 describe-instances --query "Reservations[*].Instances[*].[InstanceId, PublicIpAddress, PrivateIpAddress, Tags[?Key=='Name'].Value | [0]]" --output table
```

We can get our IP address and ssh into it.

In our terraform main.tf file, we created a key pair and created a .ssh folder to add the private key there while the public key was created inside the EC2 instance.
![image](https://github.com/user-attachments/assets/e885b14a-d804-4c37-95fb-8b58aa8bc8de)

— ssh .ssh/secret-private-key.pem ubuntu@your-ec2-instance-ip-address
![image](https://github.com/user-attachments/assets/d841f3ed-d2cb-4777-87f4-4e81e4aca5fe)


13. Create a folder called ansible

Create a file called hosts.ini inside this ansible folder.
Add the following content into the hosts.ini file:
```
[Cloudwatch]
localhost ansible_connection=local

```
14. Create the Configure-aws-cli.yml file:
– nano configure-aws-cli.yml 
```
---
- name: Install and configure AWS CLI for ubuntu user
  hosts: all
  become: yes
  vars_files:
  - aws_credentials.yml


  tasks:
    - name: Install dependencies
      apt:
        name: [unzip, curl]
        state: present
        update_cache: yes


    - name: Download AWS CLI v2
      get_url:
        url: https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip
        dest: /tmp/awscliv2.zip


    - name: Unzip AWS CLI
      unarchive:
        src: /tmp/awscliv2.zip
        dest: /tmp
        remote_src: yes


    - name: Install AWS CLI
      command: /tmp/aws/install
      args:
        creates: /usr/local/bin/aws


    - name: Create .aws directory for ubuntu user
      file:
        path: /home/ubuntu/.aws
        state: directory
        mode: '0700'
        owner: ubuntu
        group: ubuntu


    - name: Write AWS credentials for ubuntu user
      copy:
        dest: /home/ubuntu/.aws/credentials
        content: |
          [default]
          aws_access_key_id={{ aws_access_key_id }}
          aws_secret_access_key={{ aws_secret_access_key }}
        mode: '0600'
        owner: ubuntu
        group: ubuntu


    - name: Write AWS config for ubuntu user
      copy:
        dest: /home/ubuntu/.aws/config
        content: |
          [default]
          region={{ aws_region }}
          output=json
        mode: '0600'
        owner: ubuntu
        group: ubuntu


#ansible-vault create aws_credentials.yml
# aws_access_key_id: "YOUR_AWS_ACCESS_KEY_ID"
# aws_secret_access_key: "YOUR_AWS_SECRET_ACCESS_KEY"
# aws_region: "us-east-1"
#vars_files:
#  - aws_credentials.yml
```

15. We’d be using ansible-vault for security reasons. We need to reduce how much we expose our important credentials.
After creating the file:
Run:
```
– ansible-vault create aws_credentials.yml
```

Add your password
And confirm it by repeating it.
It would automatically open a vi file. So to add, click i - for insert
```
aws_access_key_id: "YOUR_AWS_ACCESS_KEY_ID"
aws_secret_access_key: "YOUR_AWS_SECRET_ACCESS_KEY"
aws_region: "us-east-1"
```
Add the correct keys in your case.

So to save, press:
:wq

![image](https://github.com/user-attachments/assets/b22cf979-2e8a-4bcd-af36-e75bd3bca265)

Run:
```
– ansible-playbook -i hosts.ini configure-aws-cli.yml –ask-vault-pass
```
This would bring out a prompt where you would have to add your password created earlier. Do this and press enter. It should run the playbook.

![image](https://github.com/user-attachments/assets/d8828c63-839b-4c40-b351-8227415b2d2b)


16. Create the file configure-monitoring-agents.yml to install SSM and cloudwatch agent.

Configure-monitoring-agents.yml

```
- name: Install and configure CloudWatch Agent, and SSM Agent on Ubuntu EC2
  hosts: Cloudwatch
  become: yes


  tasks:
    # -------- CloudWatch Agent --------
    - name: Download CloudWatch Agent .deb package
      get_url:
        url: "https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb"
        dest: /tmp/amazon-cloudwatch-agent.deb


    - name: Install CloudWatch Agent
      apt:
        deb: /tmp/amazon-cloudwatch-agent.deb


    - name: Start CloudWatch Agent
      command: >
        /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl
        -a start


    # -------- SSM Agent --------
    - name: Install SSM Agent using snap
      snap:
        name: amazon-ssm-agent
        classic: yes
        state: present


    - name: Start SSM Agent service
      systemd:
        name: snap.amazon-ssm-agent.amazon-ssm-agent
        state: started
        enabled: yes

```

Run the ansible playbook:
```
– ansible-playbook -i hosts.ini configure-monitoring-agents.yml
```

You should see something like this
![image](https://github.com/user-attachments/assets/c21e6727-3a8f-4353-88c8-b972ffa21b88)


Create the final file configure-nginx-and-metrics.yml to install Nginx and set up monitoring on cloudwatch

Configure-nginx-and-metrics.yml
```ansible
- name: Install Nginx and setup CloudWatch custom metrics
  hosts: Cloudwatch
  become: yes
 
  tasks:
    # Install Nginx based on OS type
    - name: Install Nginx (Ubuntu/Debian)
      apt:
        name: nginx
        state: present
        update_cache: yes
      when: ansible_os_family == "Debian"


    - name: Install Nginx (Amazon Linux/CentOS/RHEL)
      yum:
        name: nginx
        state: present
      when: ansible_os_family in ["RedHat", "Amazon"]


    - name: Start and enable Nginx
      systemd:
        name: nginx
        state: started
        enabled: yes


    # Create custom resource monitoring script
    - name: Create custom resource usage script
      copy:
        dest: /tmp/system-metrics.sh
        mode: '0755'
        content: |
          #!/bin/bash
          while true; do
            # Memory Usage Percentage
            memory_usage=$(free | grep Mem | awk '{print $3/$2 * 100.0}')
           
            # CPU Usage Percentage
            cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
           
            # Disk Usage Percentage
            disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')


            # Instance ID retrieval
            instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)


            # Send metrics to CloudWatch
            aws cloudwatch put-metric-data --metric-name Memory1Usage --namespace Custom --value $memory_usage --dimensions InstanceId=$instance_id --unit Percent
            aws cloudwatch put-metric-data --metric-name CPU1Usage --namespace Custom --value $cpu_usage --dimensions InstanceId=$instance_id --unit Percent
            aws cloudwatch put-metric-data --metric-name Disk1Usage --namespace Custom --value $disk_usage --dimensions InstanceId=$instance_id --unit Percent


            # Fetch CloudWatch metrics (not necessary but included)
            aws cloudwatch get-metric-statistics --metric-name Memory1Usage --namespace Custom --dimensions Name=InstanceId,Value=$instance_id --statistics Average --start-time $(date -u -d '10 minutes ago' +'%Y-%m-%dT%H:%M:%SZ') --end-time $(date -u +'%Y-%m-%dT%H:%M:%SZ') --period 60
            aws cloudwatch get-metric-statistics --metric-name CPU1Usage --namespace Custom --dimensions Name=InstanceId,Value=$instance_id --statistics Average --start-time $(date -u -d '10 minutes ago' +'%Y-%m-%dT%H:%M:%SZ') --end-time $(date -u +'%Y-%m-%dT%H:%M:%SZ') --period 60
            aws cloudwatch get-metric-statistics --metric-name Disk1Usage --namespace Custom --dimensions Name=InstanceId,Value=$instance_id --statistics Average --start-time $(date -u -d '10 minutes ago' +'%Y-%m-%dT%H:%M:%SZ') --end-time $(date -u +'%Y-%m-%dT%H:%M:%SZ') --period 60
           
            sleep 60
          done &


    - name: Run resource usage script in background
      shell: nohup sudo -u ubuntu /tmp/system-metrics.sh >/dev/null 2>&1 &
```

Run the playbook:
```bash
– ansible-playbook-i hosts.ini configure-nginx-and-metrics.yml
```
![image](https://github.com/user-attachments/assets/a113321e-be2f-49f5-ad6a-2a6175e81201)

You should see this:

![image](https://github.com/user-attachments/assets/a5d6b7da-64b6-4db6-90ee-c3a9b0dacb65)

If you go to your cloudwatch dashboard and navigate to All metrics, you’d see this:
![image](https://github.com/user-attachments/assets/7ee01467-35dd-40a9-90e6-d8b2f322a17d)

![image](https://github.com/user-attachments/assets/4a1706f5-fc4c-424a-9db7-d217349194b0)

Now you can check the metrics you set up which was to monitor memory, disk space and CPU of the server (EC2).

When you click on custom you’d see:

![image](https://github.com/user-attachments/assets/7db2b3d1-7a5c-49c1-b33b-91e6d8192071)

Then:
![image](https://github.com/user-attachments/assets/90c24524-2c70-4759-a8b9-905ebc461b30)

Check the three metrics,
Finally: 
Click on Graphed metrics (3)

![image](https://github.com/user-attachments/assets/5e9b9322-4cbd-48fd-b462-48aeac630a0e)

![image](https://github.com/user-attachments/assets/56b67111-955a-46b3-b4cf-6f37111120d3)

When it starts getting readings, it’d begin to show on the graph.

Up next is to create our AMI.
Run the following command to create an AMI:
```
— aws ec2 create-image --instance-id $(curl -s http://169.254.169.254/latest/meta-data/instance-id) --name "MyCustomAMI" --no-reboot
```
![image](https://github.com/user-attachments/assets/ef5b9576-7e2a-45e0-ac5c-d7a5a0d8dbe9)

Then run:
```
– aws ec2 describe-images --owners self
```
To confirm.

You can also check your console:
Search for AMIs
![image](https://github.com/user-attachments/assets/971c093b-45d2-4229-b73f-763f93d21c2f)


Now you have your AMI ready to be launched at anytime without the need to start reconfiguring from scratch anymore.

Just spin up your EC2 instance and continue working from there. 


