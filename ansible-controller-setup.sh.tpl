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
