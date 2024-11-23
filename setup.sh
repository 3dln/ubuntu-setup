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

# Function to get and validate username
get_username() {
    local username
    
    # If no argument provided, try to use SUDO_USER
    if [ $# -eq 0 ]; then
        if [ -n "${SUDO_USER:-}" ]; then
            username="$SUDO_USER"
        else
            log "Error: No username provided and SUDO_USER is not set"
            log "Usage: sudo bash setup.sh [USERNAME]"
            exit 1
        fi
    else
        username="$1"
    fi
    
    # Check if username exists
    if ! id "$username" &>/dev/null; then
        log "Error: User $username does not exist"
        exit 1
    fi
    
    echo "$username"
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
    local username="$1"
    
    if ! command -v docker &>/dev/null; then
        log "Installing Docker..."
        
        # Remove any conflicting packages
        local CONFLICTING_PACKAGES=(
            docker.io
            docker-doc
            docker-compose
            docker-compose-v2
            podman-docker
            containerd
            runc
        )
        
        for pkg in "${CONFLICTING_PACKAGES[@]}"; do
            apt-get remove -y "$pkg" || true
        done
        
        # Install required packages for Docker repository
        apt-get update
        apt-get install -y ca-certificates curl
        
        # Setup Docker's official GPG key
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc
        
        # Add Docker repository
        echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
            $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
            tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Update apt repo
        apt-get update
        
        # Install Docker packages
        apt-get install -y \
            docker-ce \
            docker-ce-cli \
            containerd.io \
            docker-buildx-plugin \
            docker-compose-plugin || {
            log "Error: Docker installation failed"
            exit 1
        }
        
        # Verify installation
        if ! docker run hello-world &>/dev/null; then
            log "Warning: Docker installation verification failed"
        else
            log "Docker installation verified successfully"
        }
    else
        log "Docker is already installed"
    fi
    
    # Add user to docker group
    if ! groups "$username" | grep -q '\bdocker\b'; then
        log "Adding user to docker group..."
        usermod -aG docker "$username"
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

# Function to cleanup Docker installation
cleanup_docker() {
    log "Cleaning up Docker installation..."
    
    # Stop and remove all containers, images, volumes
    if command -v docker &>/dev/null; then
        docker system prune -af --volumes || true
    fi
    
    # Remove Docker packages
    apt-get purge -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin \
        docker-ce-rootless-extras || true
    
    # Remove Docker files
    rm -rf /var/lib/docker
    rm -rf /var/lib/containerd
    
    # Remove Docker repository files
    rm -f /etc/apt/sources.list.d/docker.list
    rm -f /etc/apt/keyrings/docker.asc
    
    log "Docker cleanup completed"
}

# Main execution
main() {
    # Initial checks
    check_root
    
    # Get and validate username (either from argument or SUDO_USER)
    local username
    username=$(get_username "$@")
    
    log "Starting setup for user: $username"
    
    # System setup
    install_basic_packages
    setup_docker "$username"
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

# Execute main function with all provided arguments
main "$@"
