#!/bin/bash

# Script: docker-install.sh
# Description: Automated Docker Engine installation on Ubuntu from official Docker repository
# Usage: sudo ./docker-install.sh
# Version: 2.0

set -e  # Exit on any error
set -o pipefail  # Exit on pipe failures

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1" >&2
}

# Function to check if command executed successfully
check_success() {
    if [ $? -eq 0 ]; then
        print_status "$1"
        return 0
    else
        print_error "$2"
        exit 1
    fi
}

# Function to check internet connectivity
check_internet() {
    print_info "Checking internet connectivity..."
    if curl -s --connect-timeout 10 https://download.docker.com > /dev/null; then
        print_status "Internet connection is available"
    else
        print_error "No internet connection or Docker repository is unreachable"
        exit 1
    fi
}

# Function to check if Docker is already installed
check_existing_docker() {
    if command -v docker &> /dev/null; then
        CURRENT_VERSION=$(docker --version | awk '{print $3}' | tr -d ',')
        print_warning "Docker is already installed (version: $CURRENT_VERSION)"
        read -p "Do you want to reinstall Docker? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Installation cancelled by user"
            exit 0
        fi
    fi
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root or with sudo"
    echo "Try: sudo $0"
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

# Check for existing Docker installation
check_existing_docker

# Check internet connectivity
check_internet

# 1. Remove old Docker versions
print_info "Removing old Docker packages..."
OLD_PACKAGES="docker docker-engine docker.io containerd runc podman-docker docker-doc docker-compose docker-compose-v2"
for pkg in $OLD_PACKAGES; do
    if dpkg -l | grep -q "^ii.*$pkg"; then
        apt-get remove -y --purge "$pkg" 2>/dev/null
    fi
done

# Remove Docker data directories if they exist
if [[ -d /var/lib/docker ]]; then
    print_warning "Removing old Docker data from /var/lib/docker..."
    rm -rf /var/lib/docker
fi

if [[ -d /var/lib/containerd ]]; then
    print_warning "Removing old containerd data from /var/lib/containerd..."
    rm -rf /var/lib/containerd
fi

print_status "Old Docker packages and data removed"

# 2. Update system
print_info "Updating package list..."
apt-get update -qq
check_success "Package list updated" "Failed to update package list"

# 3. Install prerequisites
print_info "Installing prerequisites..."
apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    apt-transport-https
check_success "Prerequisites installed" "Failed to install prerequisites"

# 4. Add Docker's official GPG key
print_info "Adding Docker's GPG key..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
check_success "Docker GPG key downloaded" "Failed to download Docker GPG key"

chmod 644 /etc/apt/keyrings/docker.asc
check_success "GPG key permissions set" "Failed to set GPG key permissions"

# 5. Add Docker repository
print_info "Adding Docker repository..."
UBUNTU_CODENAME=${UBUNTU_CODENAME:-$VERSION_CODENAME}

# Check if repository already exists
if ! grep -qr "download.docker.com" /etc/apt/sources.list.d/ 2>/dev/null; then
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
    https://download.docker.com/linux/ubuntu $UBUNTU_CODENAME stable" > /etc/apt/sources.list.d/docker.list
    check_success "Docker repository added" "Failed to add Docker repository"
else
    print_warning "Docker repository already exists"
fi

# 6. Update package list with new repository
print_info "Updating package list with Docker repository..."
apt-get update -qq
check_success "Package list updated with Docker repository" "Failed to update package list"

# 7. Install Docker Engine
print_info "Installing Docker Engine..."
apt-get install -y --no-install-recommends \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin
check_success "Docker Engine installed" "Failed to install Docker Engine"

# 8. Configure Docker daemon
print_info "Configuring Docker daemon..."
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF
check_success "Docker daemon configured" "Failed to configure Docker daemon"

# 9. Start and enable Docker service
print_info "Starting Docker service..."
systemctl daemon-reload
systemctl enable docker
systemctl start docker
check_success "Docker service started and enabled" "Failed to start Docker service"

# 10. Verify installation
print_info "Verifying Docker installation..."
if docker --version &> /dev/null; then
    DOCKER_VERSION=$(docker --version | awk '{print $3}' | tr -d ',')
    DOCKER_COMPOSE_VERSION=$(docker compose version 2>/dev/null | awk '{print $4}' || echo "Not installed")
    print_status "Docker $DOCKER_VERSION installed successfully"
    print_status "Docker Compose $DOCKER_COMPOSE_VERSION"
else
    print_error "Docker installation verification failed"
    exit 1
fi

# 11. Test Docker with hello-world
print_info "Testing Docker with hello-world container..."
if docker pull hello-world &> /dev/null && docker run --rm hello-world &> /dev/null; then
    print_status "Docker is working correctly!"
else
    print_warning "Docker installed but test container failed to run"
fi

# 12. Show Docker status
echo ""
print_info "Docker service status:"
systemctl status docker --no-pager | head -20

# 13. Show Docker info
echo ""
print_info "Docker system information:"
docker info 2>/dev/null | grep -E "Containers|Images|Server Version|Storage Driver|Total Memory" || true

# 14. Post-installation steps suggestion
echo ""
print_status "=== Docker installation completed successfully! ==="
echo ""
print_info "Post-installation steps:"
echo "1. To run Docker as non-root user, add your user to 'docker' group:"
echo "   sudo usermod -aG docker \$USER"
echo ""
echo "2. Log out and log back in for group changes to take effect"
echo ""
echo "3. Test Docker without sudo:"
echo "   docker ps"
echo ""
echo "4. Useful commands:"
echo "   - Check Docker status: sudo systemctl status docker"
echo "   - Stop Docker: sudo systemctl stop docker"
echo "   - Start Docker: sudo systemctl start docker"
echo "   - View logs: sudo journalctl -u docker"
echo ""
print_info "For more information, visit: https://docs.docker.com/engine/install/ubuntu/"

# Optional: Create docker group if it doesn't exist
if ! getent group docker > /dev/null; then
    groupadd docker
    print_status "Created 'docker' group"
fi
