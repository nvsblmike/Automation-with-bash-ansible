#!/bin/bash

# Exit immediately if any command fails
set -e

# Step 1: Get instance information from AWS
echo "[*] Fetching instance details..."
INSTANCE_INFO=$(aws ec2 describe-instances \
  --query "Reservations[*].Instances[*].[InstanceId, PublicIpAddress, PrivateIpAddress, Tags[?Key=='Name'].Value | [0]]" \
  --output text)

# Step 2: Extract Public IP
PUBLIC_IP=$(echo "$INSTANCE_INFO" | awk 'NR==1 {print $2}')
echo "[*] Public IP extracted: $PUBLIC_IP"

# Step 3: SSH into the server and create necessary files
echo "[*] Connecting to server via SSH..."
ssh -i .ssh/secret-key.pem ubuntu@$PUBLIC_IP << 'EOF'
  echo "[*] Creating configuration files on remote server..."

  # Create directory to hold config files
  mkdir -p ~/ansible-setup
  cd ~/ansible-setup

  # Receive files from local machine
  echo "[*] Waiting for files to be copied from local machine..."
EOF

# Step 4: Copy Ansible files to the remote server
echo "[*] Copying Ansible files to server..."
scp -i .ssh/secret-key.pem \
  hosts.ini configure-aws-cli.yml configure-monitoring-agents.yml configure-nginx-and-metrics.yml \
  ubuntu@$PUBLIC_IP:~/ansible-setup/

# Step 5: Create ansible-vault file using password
echo "[*] Creating Ansible Vault file..."
VAULT_PASSWORD="nvsblmike1925"
cat <<EOF > aws_credentials.yml.tmp
aws_access_key: YOUR_AWS_ACCESS_KEY
aws_secret_key: YOUR_AWS_SECRET_KEY
region: YOUR_AWS_REGION
EOF

# Encrypt the file with Ansible Vault
ansible-vault encrypt aws_credentials.yml.tmp --output aws_credentials.yml --vault-password-file=<(echo "$VAULT_PASSWORD")

# Copy the vault file
scp -i .ssh/secret-key.pem aws_credentials.yml ubuntu@$PUBLIC_IP:~/ansible-setup/

# Step 6: Run Ansible playbook with Vault
echo "[*] Running Ansible Playbooks..."
ssh -i .ssh/secret-key.pem ubuntu@$PUBLIC_IP << EOF
  cd ~/ansible-setup
  echo "$VAULT_PASSWORD" > .vault_pass.txt

  ansible-playbook -i hosts.ini configure-aws-cli.yml --vault-password-file .vault_pass.txt
  ansible-playbook -i hosts.ini configure-monitoring-agents.yml
  ansible-playbook -i hosts.ini configure-nginx-and-metrics.yml

  rm .vault_pass.txt
EOF

# Cleanup
rm -f aws_credentials.yml aws_credentials.yml.tmp

echo "[✓] Deployment and configuration completed successfully."
