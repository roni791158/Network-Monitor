#!/bin/bash

# Network Monitor Installation Script for OpenWrt
# Version: 1.0.0

set -e

PACKAGE_NAME="network-monitor"
GITHUB_REPO="https://github.com/roni791158/Network-Monitor"
TEMP_DIR="/tmp/netmon-install"
INSTALL_DIR="/opt/netmon"

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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check system requirements
check_requirements() {
    print_status "Checking system requirements..."
    
    # Check if we're on OpenWrt
    if [ ! -f /etc/openwrt_release ]; then
        print_warning "This script is designed for OpenWrt systems"
    fi
    
    # Check for required commands
    local missing_deps=0
    
    for cmd in wget tar iptables; do
        if ! command_exists "$cmd"; then
            print_error "Required command not found: $cmd"
            missing_deps=$((missing_deps + 1))
        fi
    done
    
    if [ $missing_deps -gt 0 ]; then
        print_error "Missing dependencies. Please install the required packages."
        exit 1
    fi
    
    print_success "System requirements check passed"
}

# Function to install dependencies
install_dependencies() {
    print_status "Installing dependencies..."
    
    # Update package list
    opkg update
    
    # Install required packages
    local packages="libnetfilter-log libnetfilter-queue iptables uhttpd cgi-io rpcd libiwinfo luci-lib-json luci-lib-nixio sqlite3-cli libsqlite3"
    
    for package in $packages; do
        print_status "Installing $package..."
        if opkg install "$package" 2>/dev/null; then
            print_success "Installed $package"
        else
            print_warning "Failed to install $package (may already be installed)"
        fi
    done
}

# Function to download and extract package
download_package() {
    print_status "Downloading Network Monitor package..."
    
    # Create temp directory
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    # Download latest release
    if command_exists curl; then
        curl -L -o netmon.tar.gz "${GITHUB_REPO}/archive/main.tar.gz"
    elif command_exists wget; then
        wget -O netmon.tar.gz "${GITHUB_REPO}/archive/main.tar.gz"
    else
        print_error "Neither curl nor wget found. Cannot download package."
        exit 1
    fi
    
    # Extract package
    tar -xzf netmon.tar.gz
    cd Network-Monitor-main
    
    print_success "Package downloaded and extracted"
}

# Function to download precompiled binary
download_precompiled_binary() {
    print_status "Detecting system architecture..."
    
    # Detect architecture
    local arch=$(uname -m)
    local openwrt_arch=""
    
    case "$arch" in
        "aarch64")
            openwrt_arch="aarch64_cortex-a53"
            ;;
        "armv7l"|"armv6l")
            openwrt_arch="arm_cortex-a7"
            ;;
        "mips")
            openwrt_arch="mips_24kc"
            ;;
        "mipsel")
            openwrt_arch="mipsel_24kc"
            ;;
        "x86_64")
            openwrt_arch="x86_64"
            ;;
        "i386"|"i686")
            openwrt_arch="i386_pentium4"
            ;;
        *)
            print_error "Unsupported architecture: $arch"
            print_error "Please install build tools and compile from source:"
            print_error "opkg update && opkg install make gcc"
            exit 1
            ;;
    esac
    
    print_status "Architecture detected: $openwrt_arch"
    
    # Download precompiled binary (fallback to a simple shell script for now)
    print_warning "Precompiled binaries not yet available. Creating minimal shell wrapper..."
    
    # Create a minimal shell script wrapper that will work without compilation
    cat > /usr/bin/netmon << 'EOF'
#!/bin/sh

# Network Monitor Shell Wrapper
# This is a minimal implementation that provides basic functionality

PIDFILE="/var/run/netmon.pid"
LOGFILE="/var/log/netmon/netmon.log"
DBFILE="/var/lib/netmon/netmon.db"

# Create directories
mkdir -p /var/lib/netmon /var/log/netmon

# Initialize database with SQLite if available
init_db() {
    if command -v sqlite3 >/dev/null 2>&1; then
        sqlite3 "$DBFILE" << 'SQL'
CREATE TABLE IF NOT EXISTS devices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ip TEXT UNIQUE NOT NULL,
    mac TEXT,
    hostname TEXT,
    first_seen INTEGER,
    last_seen INTEGER,
    is_active INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS traffic (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ip TEXT NOT NULL,
    url TEXT,
    timestamp INTEGER,
    bytes_sent INTEGER,
    bytes_received INTEGER
);

CREATE INDEX IF NOT EXISTS idx_devices_ip ON devices(ip);
CREATE INDEX IF NOT EXISTS idx_traffic_ip ON traffic(ip);
CREATE INDEX IF NOT EXISTS idx_traffic_timestamp ON traffic(timestamp);
SQL
        echo "Database initialized" >> "$LOGFILE"
    fi
}

# Monitor network devices
monitor_devices() {
    while [ -f "$PIDFILE" ]; do
        # Get current timestamp
        TIMESTAMP=$(date +%s)
        
        # Parse ARP table for connected devices
        if [ -f /proc/net/arp ]; then
            awk 'NR>1 && $3!="00:00:00:00:00:00" && $1!="IP" {
                print $1, $4, $6, "'$TIMESTAMP'"
            }' /proc/net/arp | while read ip mac device timestamp; do
                if command -v sqlite3 >/dev/null 2>&1; then
                    # Try to get hostname
                    hostname=$(nslookup "$ip" 2>/dev/null | awk '/name =/ {gsub(/\.$/, "", $4); print $4; exit}')
                    [ -z "$hostname" ] && hostname="Unknown Device"
                    
                    # Insert or update device
                    sqlite3 "$DBFILE" "INSERT OR REPLACE INTO devices (ip, mac, hostname, first_seen, last_seen, is_active) VALUES ('$ip', '$mac', '$hostname', $timestamp, $timestamp, 1);"
                fi
                echo "$(date): Device detected - IP: $ip, MAC: $mac" >> "$LOGFILE"
            done
        fi
        
        # Sleep for 60 seconds
        sleep 60
    done
}

case "$1" in
    --init-db)
        init_db
        ;;
    start)
        if [ -f "$PIDFILE" ]; then
            echo "Network Monitor is already running"
            exit 1
        fi
        echo $$ > "$PIDFILE"
        echo "$(date): Network Monitor started" >> "$LOGFILE"
        init_db
        monitor_devices &
        ;;
    stop)
        if [ -f "$PIDFILE" ]; then
            PID=$(cat "$PIDFILE")
            kill "$PID" 2>/dev/null
            rm -f "$PIDFILE"
            echo "$(date): Network Monitor stopped" >> "$LOGFILE"
        fi
        ;;
    status)
        if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
            echo "Network Monitor is running"
            exit 0
        else
            echo "Network Monitor is not running"
            exit 1
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|status|--init-db}"
        exit 1
        ;;
esac
EOF
    
    chmod +x /usr/bin/netmon
    print_success "Network Monitor wrapper installed"
}

# Function to install package files
install_files() {
    print_status "Installing package files..."
    
    # Create directories
    mkdir -p /usr/bin
    mkdir -p /etc/init.d
    mkdir -p /etc/config
    mkdir -p /www/netmon
    mkdir -p /usr/lib/lua/luci/controller
    mkdir -p /usr/lib/lua/luci/model/cbi
    mkdir -p /usr/lib/lua/luci/view/netmon
    mkdir -p /var/lib/netmon
    mkdir -p /var/log/netmon
    mkdir -p /www/cgi-bin
    
    # Try to compile binary if build tools are available
    print_status "Installing network monitor daemon..."
    
    if command_exists make && command_exists gcc; then
        print_status "Compiling from source..."
        cd src
        if make CC="gcc" CFLAGS="-Wall -Wextra -O2" LDFLAGS="-lnetfilter_log -lnetfilter_queue -ljson-c -lsqlite3"; then
            if [ -f netmon ]; then
                cp netmon /usr/bin/
                chmod +x /usr/bin/netmon
                print_success "Binary compiled and installed"
            else
                print_error "Failed to compile binary"
                exit 1
            fi
        else
            print_error "Compilation failed"
            exit 1
        fi
        cd ..
    else
        print_warning "Build tools not available, trying to download precompiled binary..."
        download_precompiled_binary
    fi
    
    # Install configuration files
    cp files/netmon.init /etc/init.d/netmon
    chmod +x /etc/init.d/netmon
    
    cp files/netmon.config /etc/config/netmon
    
    # Install web interface
    cp -r files/www/* /www/netmon/
    
    # Install LuCI integration
    cp files/luci/controller/netmon.lua /usr/lib/lua/luci/controller/
    cp files/luci/model/cbi/netmon.lua /usr/lib/lua/luci/model/cbi/
    cp -r files/luci/view/netmon/* /usr/lib/lua/luci/view/netmon/
    
    # Install CGI scripts
    cp files/www/cgi-bin/* /www/cgi-bin/
    chmod +x /www/cgi-bin/netmon-*.lua
    
    print_success "Package files installed"
}

# Function to configure firewall
configure_firewall() {
    print_status "Configuring firewall rules..."
    
    # Add iptables rules for packet monitoring
    iptables -I FORWARD -j NFQUEUE --queue-num 0 2>/dev/null || true
    iptables -I INPUT -j NFLOG --nflog-group 0 2>/dev/null || true
    iptables -I OUTPUT -j NFLOG --nflog-group 0 2>/dev/null || true
    
    # Save rules (if supported)
    if command_exists iptables-save; then
        iptables-save > /etc/iptables.rules 2>/dev/null || true
    fi
    
    print_success "Firewall configured"
}



# Function to start services
start_services() {
    print_status "Starting services..."
    
    # Initialize database
    print_status "Initializing database..."
    /usr/bin/netmon --init-db 2>/dev/null || true
    
    # Enable and start netmon service
    print_status "Enabling Network Monitor service..."
    /etc/init.d/netmon enable
    
    print_status "Starting Network Monitor service..."
    /etc/init.d/netmon start
    
    # Configure and restart uhttpd for web interface
    print_status "Configuring web server..."
    
    # Create uhttpd configuration for netmon port
    if ! grep -q "netmon" /etc/config/uhttpd 2>/dev/null; then
        cat >> /etc/config/uhttpd << 'EOF'

config uhttpd 'netmon'
    option listen_http '0.0.0.0:8080'
    option home '/www/netmon'
    option cgi_prefix '/cgi-bin'
    option script_timeout '60'
    option network_timeout '30'
    option tcp_keepalive '1'
EOF
    fi
    
    # Restart uhttpd
    /etc/init.d/uhttpd restart
    
    print_success "Services started"
}

# Function to display installation summary
show_summary() {
    print_success "Network Monitor installation completed successfully!"
    echo ""
    echo "Access Information:"
    echo "  Web Interface: http://$(uci get network.lan.ipaddr 2>/dev/null || echo "192.168.1.1"):8080/netmon"
    echo "  LuCI Integration: System > Administration > Network Monitor"
    echo ""
    echo "Service Management:"
    echo "  Start: /etc/init.d/netmon start"
    echo "  Stop: /etc/init.d/netmon stop"
    echo "  Restart: /etc/init.d/netmon restart"
    echo "  Status: /etc/init.d/netmon status"
    echo ""
    echo "Configuration:"
    echo "  Config file: /etc/config/netmon"
    echo "  Data directory: /var/lib/netmon"
    echo "  Log directory: /var/log/netmon"
    echo ""
    echo "For support, visit: ${GITHUB_REPO}"
}

# Function to cleanup
cleanup() {
    print_status "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
    print_success "Cleanup completed"
}

# Main installation function
main() {
    echo "============================================"
    echo "Network Monitor Installation Script"
    echo "Version: 1.0.0"
    echo "============================================"
    echo ""
    
    # Check if running as root
    if [ "$(id -u)" != "0" ]; then
        print_error "This script must be run as root"
        exit 1
    fi
    
    # Run installation steps
    check_requirements
    install_dependencies
    download_package
    install_files
    configure_firewall
    start_services
    show_summary
    cleanup
    
    echo ""
    print_success "Installation completed! Network Monitor is now running."
}

# Run main function
main "$@"
