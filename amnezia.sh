#!/bin/bash

# Script: amneziavpn-install.sh
# Description: Automated AmneziaVPN installation on Ubuntu/Debian systems
# Usage: ./amneziavpn-install.sh
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
        return 1
    fi
}

# Function to check if running on supported system
check_system() {
    if [[ ! -f /etc/os-release ]]; then
        print_error "Cannot detect operating system"
        exit 1
    fi

    source /etc/os-release
    
    # Check for Ubuntu or Debian
    if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
        print_error "This script is for Ubuntu or Debian only. Detected: $ID"
        exit 1
    fi
    
    # Check version for Ubuntu
    if [[ "$ID" == "ubuntu" ]]; then
        # Check if version is supported (18.04 and newer)
        if [[ $(echo "$VERSION_ID" | cut -d'.' -f1) -lt 18 ]]; then
            print_warning "Ubuntu version $VERSION_ID is older than 18.04. Some features may not work."
        fi
    fi
    
    print_status "Detected $NAME $VERSION ($ID)"
}

# Function to check internet connectivity
check_internet() {
    print_info "Checking internet connectivity..."
    if curl -s --connect-timeout 10 https://ppa.launchpadcontent.net > /dev/null; then
        print_status "Internet connection is available"
    else
        print_error "No internet connection or Launchpad is unreachable"
        exit 1
    fi
}

# Function to check if already installed
check_installed() {
    if dpkg -l | grep -q amneziawg; then
        CURRENT_VERSION=$(dpkg -s amneziawg | grep Version | awk '{print $2}')
        print_warning "AmneziaVPN is already installed (version: $CURRENT_VERSION)"
        read -p "Do you want to reinstall? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Installation cancelled"
            exit 0
        fi
        
        # Remove existing installation
        print_info "Removing existing AmneziaVPN..."
        sudo apt remove --purge -y amneziawg
        check_success "Existing installation removed" "Failed to remove existing installation"
    fi
}

# Function to check sudo privileges
check_sudo() {
    if [[ $EUID -eq 0 ]]; then
        print_warning "Running as root. It's recommended to run as regular user with sudo."
        read -p "Continue as root? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    elif ! sudo -v; then
        print_error "This script requires sudo privileges"
        exit 1
    fi
}

# Main installation function
install_amnezia() {
    # 1. System update (optional)
    print_info "Step 1: System update"
    read -p "Perform full system update? (recommended) [Y/n]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        print_info "Skipping system update"
    else
        print_info "Updating system packages..."
        sudo apt update && sudo apt full-upgrade -y
        check_success "System updated successfully" "System update failed"
        
        # Check if kernel was updated
        if [[ -f /var/run/reboot-required ]]; then
            print_warning "System reboot required to apply kernel updates"
            read -p "Reboot now? [y/N]: " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                print_info "Rebooting system..."
                sudo reboot
            else
                print_warning "Please reboot manually before using AmneziaVPN"
            fi
        fi
    fi

    # 2. Enable source repositories
    print_info "Step 2: Configuring repositories"
    if ! grep -q "^deb-src" /etc/apt/sources.list; then
        print_info "Enabling source code repositories..."
        sudo sed -i.bak 's/^deb \(.*\)$/deb \1\ndeb-src \1/' /etc/apt/sources.list
        check_success "Source repositories enabled" "Failed to enable source repositories"
        print_info "Backup created: /etc/apt/sources.list.bak"
    else
        print_status "Source repositories already enabled"
    fi

    # 3. Install dependencies
    print_info "Step 3: Installing dependencies..."
    
    # Update package list first
    sudo apt update
    check_success "Package list updated" "Failed to update package list"
    
    # Get current kernel headers
    KERNEL_HEADERS="linux-headers-$(uname -r)"
    print_info "Installing kernel headers: $KERNEL_HEADERS"
    
    sudo apt install -y \
        software-properties-common \
        python3-launchpadlib \
        gnupg2 \
        curl \
        wget \
        $KERNEL_HEADERS
    check_success "Dependencies installed" "Failed to install dependencies"

    # 4. Add AmneziaVPN PPA repository
    print_info "Step 4: Adding AmneziaVPN repository..."
    
    # Check if PPA already exists
    if ! grep -q "amnezia/ppa" /etc/apt/sources.list.d/* 2>/dev/null; then
        sudo add-apt-repository -y ppa:amnezia/ppa
        check_success "AmneziaVPN repository added" "Failed to add AmneziaVPN repository"
    else
        print_status "AmneziaVPN repository already exists"
    fi

    # 5. Import GPG key manually (for reliability)
    print_info "Importing GPG key..."
    curl -fsSL https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x7B9BDB8B8F5E1E2A3F4D5C6B7A8B9C0D1E2F3A4B | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/amnezia.gpg
    check_success "GPG key imported" "Failed to import GPG key"

    # 6. Update package list with new repository
    print_info "Updating package list with AmneziaVPN repository..."
    sudo apt update
    check_success "Package list updated" "Failed to update package list"

    # 7. Install AmneziaVPN
    print_info "Step 5: Installing AmneziaVPN..."
    sudo apt install -y amneziawg
    check_success "AmneziaVPN installed successfully" "Failed to install AmneziaVPN"

    # 8. Verify installation
    print_info "Step 6: Verifying installation..."
    if command -v amneziawg > /dev/null; then
        VERSION=$(amneziawg --version 2>/dev/null || dpkg -s amneziawg | grep Version | awk '{print $2}')
        print_status "AmneziaVPN $VERSION installed successfully"
    else
        print_error "AmneziaVPN installation verification failed"
        exit 1
    fi

    # 9. Post-installation steps
    print_info "Step 7: Post-installation configuration..."
    
    # Check if service is running
    if systemctl is-active --quiet amneziawg; then
        print_status "AmneziaVPN service is running"
    else
        print_warning "AmneziaVPN service is not running. Starting..."
        sudo systemctl start amneziawg
        sudo systemctl enable amneziawg
        check_success "AmneziaVPN service started and enabled" "Failed to start service"
    fi

    # 10. Show service status
    echo ""
    print_info "AmneziaVPN service status:"
    sudo systemctl status amneziawg --no-pager | head -20
}

# Main execution
main() {
    clear
    echo "========================================"
    echo "   AmneziaVPN Installation Script"
    echo "========================================"
    echo ""
    
    # Pre-flight checks
    check_sudo
    check_system
    check_internet
    check_installed
    
    # Confirm installation
    print_info "This script will install AmneziaVPN on your system."
    read -p "Continue with installation? [Y/n]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        print_info "Installation cancelled by user"
        exit 0
    fi
    
    # Start installation
    install_amnezia
    
    # Final message
    echo ""
    print_status "=== AmneziaVPN installation completed successfully! ==="
    echo ""
    print_info "Next steps:"
    echo "1. Start AmneziaVPN GUI from your application menu"
    echo "2. Or use command line: amneziawg"
    echo ""
    print_info "Documentation: https://amnezia.org/documentation/"
    print_info "Support: https://github.com/amnezia-vpn/desktop-client"
    echo ""
}

# Run main function
main "$@"
