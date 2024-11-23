#!/bin/bash

# Script name: setup.sh
# Description: Initial server setup script for Ubuntu with Docker installation
# Usage: sudo bash setup.sh [USERNAME]

# Exit on any error
set -e

# Exit on undefined variable
set -u

# Pipeline returns exit status of last command to fail in a pipeline
set -o pipefail

# Function to log messages
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check if script is run with root privileges
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log "Error: This script must be run as root (use sudo)"
        exit 1
    fi
}

# Function to validate username
validate_username() {
    if [ $# -eq 0 ]; then
        log "Error: Please provide a username as an argument"
        log "Usage: sudo bash setup.sh [USERNAME]"
        exit 1
    fi
    
    # Check if username exists
    if ! id "$1" &>/dev/null; then
        log "Error: User $1 does not exist"
        exit 1
    fi
}

# Function to install basic packages
install_basic_packages() {
    log "Installing basic packages..."
    apt update -y || {
        log "Error: Failed to update package list"
        exit 1
    }
    
    PACKAGES=(
        curl
        apt-transport-https
        ca-certificates
        software-properties-common
        gnupg
        lsb-release
        ufw
        fail2ban
    )
    
    apt install -y "${PACKAGES[@]}" || {
        log "Error: Failed to install basic packages"
        exit 1
    }
}

# Function to install and configure Docker
setup_docker() {
    local USERNAME=$1
    
    if ! command -v docker &>/dev/null; then
        log "Installing Docker..."
        
        # Remove any old Docker installations
        apt remove -y docker docker-engine docker.io containerd runc || true
        
        # Add Docker's official GPG key
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        
        # Add Docker repository
        echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
            $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Install Docker
        apt update
        apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin || {
            log "Error: Docker installation failed"
            exit 1
        }
    else
        log "Docker is already installed"
    fi
    
    # Add user to docker group
    if ! groups "$USERNAME" | grep -q '\bdocker\b'; then
        log "Adding user to docker group..."
        usermod -aG docker "$USERNAME"
        log "Note: Please log out and log back in for docker group changes to take effect"
    fi
    
    # Enable and start Docker service
    systemctl enable docker
    systemctl start docker
}

# Function to configure UFW firewall
setup_firewall() {
    log "Configuring UFW firewall..."
    
    # Define allowed ports
    local PORTS=(
        22/tcp    # SSH
        80/tcp    # HTTP
        443/tcp   # HTTPS
        81/tcp    # Alternative HTTP (e.g., for Portainer)
    )
    
    # Allow necessary ports
    for port in "${PORTS[@]}"; do
        ufw allow "$port"
    done
    
    # Enable UFW if not already enabled
    if ! ufw status | grep -q "Status: active"; then
        log "Enabling UFW..."
        ufw --force enable
    else
        log "UFW is already enabled"
    fi
}

# Function to setup fail2ban
setup_fail2ban() {
    log "Configuring fail2ban..."
    
    # Create fail2ban jail configuration
    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = %(sshd_log)s
maxretry = 3
EOF

    # Restart fail2ban
    systemctl restart fail2ban
}

# Function to secure SSH
secure_ssh() {
    log "Securing SSH configuration..."
    
    # Backup original sshd_config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    
    # Configure SSH
    sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/X11Forwarding yes/X11Forwarding no/' /etc/ssh/sshd_config
    
    # Restart SSH service
    systemctl restart sshd
}

# Main execution
main() {
    local USERNAME=$1
    
    # Initial checks
    check_root
    validate_username "$USERNAME"
    
    # System setup
    install_basic_packages
    setup_docker "$USERNAME"
    setup_firewall
    setup_fail2ban
    secure_ssh
    
    log "Setup completed successfully!"
    log "Security Recommendations:"
    log "1. Make sure to set up SSH keys if not already done"
    log "2. Consider setting up automated security updates"
    log "3. Review and adjust UFW rules based on your needs"
    log "4. Log out and log back in for docker group changes to take effect"
}

# Execute main function with provided username
main "$@"