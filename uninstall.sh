#!/bin/bash

# Network Monitor Uninstallation Script for OpenWrt
# Version: 1.0.0

set -e

PACKAGE_NAME="network-monitor"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to confirm uninstallation
confirm_uninstall() {
    echo "============================================"
    echo "Network Monitor Uninstallation Script"
    echo "Version: 1.0.0"
    echo "============================================"
    echo ""
    print_warning "This will completely remove Network Monitor from your system."
    print_warning "All monitoring data will be permanently deleted."
    echo ""
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Uninstallation cancelled."
        exit 0
    fi
}

# Function to stop services
stop_services() {
    print_status "Stopping Network Monitor services..."
    
    # Stop netmon service
    if [ -f /etc/init.d/netmon ]; then
        /etc/init.d/netmon stop 2>/dev/null || true
        /etc/init.d/netmon disable 2>/dev/null || true
        print_success "Network Monitor service stopped"
    fi
}

# Function to remove firewall rules
remove_firewall_rules() {
    print_status "Removing firewall rules..."
    
    # Remove iptables rules (if they exist)
    iptables -D FORWARD -j NFQUEUE --queue-num 0 2>/dev/null || true
    iptables -D INPUT -j NFLOG --nflog-group 0 2>/dev/null || true
    iptables -D OUTPUT -j NFLOG --nflog-group 0 2>/dev/null || true
    
    print_success "Firewall rules removed"
}

# Function to remove files and directories
remove_files() {
    print_status "Removing application files..."
    
    # Remove binary
    rm -f /usr/bin/netmon
    
    # Remove init script
    rm -f /etc/init.d/netmon
    
    # Remove configuration
    rm -f /etc/config/netmon
    
    # Remove web interface
    rm -rf /www/netmon
    
    # Remove CGI scripts
    rm -f /www/cgi-bin/netmon-*.lua
    
    # Remove LuCI integration
    rm -f /usr/lib/lua/luci/controller/netmon.lua
    rm -f /usr/lib/lua/luci/model/cbi/netmon.lua
    rm -rf /usr/lib/lua/luci/view/netmon
    
    # Remove uhttpd configuration
    rm -f /etc/uhttpd-netmon.conf
    
    print_success "Application files removed"
}

# Function to remove data and logs
remove_data() {
    print_status "Removing data and log files..."
    
    # Ask user about data removal
    echo ""
    read -p "Do you want to remove all monitoring data and logs? (y/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf /var/lib/netmon
        rm -rf /var/log/netmon
        print_success "Data and log files removed"
    else
        print_warning "Data and log files preserved in /var/lib/netmon and /var/log/netmon"
    fi
}

# Function to restart services
restart_services() {
    print_status "Restarting web server..."
    
    # Restart uhttpd to remove netmon configuration
    /etc/init.d/uhttpd restart 2>/dev/null || true
    
    print_success "Web server restarted"
}

# Function to show uninstall summary
show_summary() {
    print_success "Network Monitor has been uninstalled successfully!"
    echo ""
    print_status "The following may still be installed (if they were not installed by Network Monitor):"
    echo "  - libnetfilter-log"
    echo "  - libnetfilter-queue" 
    echo "  - sqlite3-cli"
    echo "  - libsqlite3"
    echo ""
    print_status "You can remove these manually if not needed by other applications:"
    echo "  opkg remove libnetfilter-log libnetfilter-queue sqlite3-cli libsqlite3"
    echo ""
    print_status "Thank you for using Network Monitor!"
}

# Function to remove dependencies (optional)
remove_dependencies() {
    echo ""
    read -p "Do you want to remove dependencies that were installed with Network Monitor? (y/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Removing dependencies..."
        
        # List of packages that were likely installed for netmon
        local packages="libnetfilter-log libnetfilter-queue"
        
        for package in $packages; do
            if opkg list-installed | grep -q "^$package "; then
                print_status "Removing $package..."
                if opkg remove "$package" 2>/dev/null; then
                    print_success "Removed $package"
                else
                    print_warning "Failed to remove $package (may be used by other applications)"
                fi
            fi
        done
    fi
}

# Main uninstallation function
main() {
    # Check if running as root
    if [ "$(id -u)" != "0" ]; then
        print_error "This script must be run as root"
        exit 1
    fi
    
    # Confirm uninstallation
    confirm_uninstall
    
    # Run uninstallation steps
    stop_services
    remove_firewall_rules
    remove_files
    remove_data
    restart_services
    remove_dependencies
    show_summary
    
    echo ""
    print_success "Uninstallation completed successfully!"
}

# Run main function
main "$@"
