#!/bin/bash

# Script: docker-install.sh
# Description: Automated Docker Engine installation on Ubuntu from official Docker repository
# Usage: sudo ./docker-install.sh

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root or with sudo"
    exit 1
fi

# Detect Ubuntu version
if [[ ! -f /etc/os-release ]]; then
    print_error "This script is for Ubuntu only"
    exit 1
fi

source /etc/os-release
if [[ "$ID" != "ubuntu" ]]; then
    print_error "This script is for Ubuntu only. Detected: $ID"
    exit 1
fi

print_status "Detected Ubuntu $VERSION_CODENAME ($VERSION_ID)"

# 1. Remove old Docker versions
print_status "Removing old Docker packages..."
REMOVE_PKGS=$(dpkg --get-selections docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc 2>/dev/null | cut -f1)
if [[ -n "$REMOVE_PKGS" ]]; then
    apt-get remove -y $REMOVE_PKGS
    print_status "Old Docker packages removed"
else
    print_warning "No old Docker packages found"
fi

# 2. Update system
print_status "Updating package list..."
apt-get update

# 3. Install prerequisites
print_status "Installing prerequisites..."
apt-get install -y ca-certificates curl gnupg lsb-release

# 4. Add Docker's official GPG key
print_status "Adding Docker's GPG key..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# 5. Add Docker repository
print_status "Adding Docker repository..."
UBUNTU_CODENAME=${UBUNTU_CODENAME:-$VERSION_CODENAME}
cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $UBUNTU_CODENAME
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

# 6. Update package list with new repository
print_status "Updating package list with Docker repository..."
apt-get update

# 7. Install Docker Engine
print_status "Installing Docker Engine..."
apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

# 8. Start and enable Docker service
print_status "Starting Docker service..."
systemctl start docker
systemctl enable docker

# 9. Verify installation
print_status "Verifying Docker installation..."
if docker --version &> /dev/null; then
    DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | tr -d ',')
    print_status "Docker $DOCKER_VERSION installed successfully"
else
    print_error "Docker installation verification failed"
    exit 1
fi

# 10. Test Docker with hello-world
print_status "Testing Docker with hello-world container..."
if docker run --rm hello-world &> /dev/null; then
    print_status "Docker is working correctly!"
else
    print_warning "Docker installed but test container failed to run"
fi

# 11. Show Docker status
echo ""
print_status "Docker service status:"
systemctl status docker --no-pager

# 12. Post-installation steps suggestion
echo ""
print_status "Post-installation steps:"
echo "1. To run Docker as non-root user, add your user to 'docker' group:"
echo "   sudo usermod -aG docker \$USER"
echo "2. Log out and log back in for group changes to take effect"
echo "3. Verify with: docker ps"

print_status "Docker installation completed!"
