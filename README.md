# Ubuntu Server Setup Script

A comprehensive setup script for initializing Ubuntu servers with Docker and essential security configurations. This script automates the process of setting up a fresh Ubuntu server with Docker, security hardening, and best practices for production environments.

## Features

- 🐳 Docker Installation and Configuration
  - Installs latest Docker Engine and Docker Compose
  - Sets up Docker user permissions
  - Configures Docker to start on boot

- 🔒 Security Hardening
  - UFW (Uncomplicated Firewall) configuration
  - fail2ban installation and setup
  - SSH hardening
  - System user permissions management

- 🛠 System Configuration
  - Essential system packages installation
  - System updates and upgrades
  - Group permission management
  - Service configuration

## Prerequisites

- Ubuntu Server (20.04 LTS or newer)
- Root or sudo privileges
- Active internet connection
- Existing user account (non-root)

## Installation

1. Download the setup script:
```bash
curl -O https://raw.githubusercontent.com/yourusername/ubuntu-setup/main/setup.sh
```

2. Make the script executable:
```bash
chmod +x setup.sh
```

3. Run the script with sudo:
```bash
# If you're logged in as the user you want to configure:
sudo ./setup.sh $SUDO_USER

# Or if you want to configure for a different user:
sudo ./setup.sh username
```

## Usage

The script must be run with sudo privileges. There are two ways to run it:

1. **For the current sudo user** (recommended):
```bash
sudo ./setup.sh $SUDO_USER
```

2. **For a specific user**:
```bash
sudo ./setup.sh username
```

Examples:
```bash
# For current sudo user
sudo ./setup.sh $SUDO_USER

# For specific user 'johndoe'
sudo ./setup.sh johndoe
```

Note: The `$SUDO_USER` environment variable automatically contains the username of the user who invoked sudo, which makes it the safest and most convenient option when setting up for your own user account.

## What Does It Configure?

### System Packages
- curl
- apt-transport-https
- ca-certificates
- software-properties-common
- gnupg
- lsb-release
- ufw
- fail2ban

### Firewall (UFW)
Opens the following ports:
- 22/tcp (SSH)
- 80/tcp (HTTP)
- 443/tcp (HTTPS)
- 81/tcp (Alternative HTTP, e.g., for Portainer)

### Security Features
1. **fail2ban**
   - Protects against brute force attacks
   - Default jail configuration
   - Custom ban times and retry limits

2. **SSH Hardening**
   - Disables root login
   - Disables password authentication
   - Disables X11 forwarding

3. **Docker Security**
   - Secure repository configuration
   - User permission management
   - Group-based access control

## Post-Installation Steps

After the script completes, you should:

1. **Log out and log back in** to apply Docker group changes
2. Set up SSH keys if not already configured
3. Review and adjust UFW rules based on your specific needs
4. Consider setting up automated security updates
5. Review system logs for any potential issues

## Maintenance

### Docker
- Docker is configured to start on boot
- Use `docker system prune` periodically to clean up unused resources
- Monitor Docker logs: `docker logs [container_name]`

### Security
- Monitor fail2ban logs: `sudo tail -f /var/log/fail2ban.log`
- Check UFW status: `sudo ufw status`
- Review auth logs: `sudo tail -f /var/log/auth.log`

## Troubleshooting

### Common Issues

1. **Docker Group Changes Not Applied**
   ```bash
   # Log out and log back in, or run:
   newgrp docker
   ```

2. **UFW Blocks Legitimate Traffic**
   ```bash
   # List UFW rules
   sudo ufw status numbered
   # Add new rule if needed
   sudo ufw allow port/tcp
   ```

3. **fail2ban Issues**
   ```bash
   # Check fail2ban status
   sudo systemctl status fail2ban
   # View current bans
   sudo fail2ban-client status
   ```

### Log Files

Important log files to check for issues:
- `/var/log/syslog` - System logs
- `/var/log/auth.log` - Authentication logs
- `/var/log/docker/` - Docker logs
- `/var/log/fail2ban.log` - fail2ban logs

## Security Recommendations

1. **SSH Key Authentication**
   - Generate SSH keys on your local machine
   - Use `ssh-copy-id` to copy public key to server
   - Ensure password authentication is disabled

2. **Regular Updates**
   ```bash
   sudo apt update
   sudo apt upgrade
   ```

3. **Monitor System Access**
   - Regular log review
   - Set up log rotation
   - Consider additional monitoring tools

4. **Backup Strategy**
   - Implement regular backups
   - Test backup restoration
   - Document backup procedures

## Contributing

Feel free to submit issues and enhancement requests!

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a new Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Docker documentation
- Ubuntu security best practices
- Community feedback and contributions

## Support

For support and questions:
- Open an issue in the repository
- Contact: your@email.com
- Documentation: [Link to your documentation]

---

**Note:** This script is provided as-is, without warranty. Always review scripts before running them on your system and ensure they meet your specific security requirements.
