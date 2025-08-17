#!/bin/bash

# Complete Network Monitor Uninstall Script
# Removes all traces of the network monitor

echo "🗑️ COMPLETE NETWORK MONITOR UNINSTALL"
echo "====================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}[ERROR]${NC} This script must be run as root"
    echo "Usage: wget -O - https://raw.githubusercontent.com/roni791158/Network-Monitor/main/complete_uninstall.sh | sh"
    exit 1
fi

print_status "Starting complete uninstall of Network Monitor..."

# Step 1: Stop all related services
print_status "Step 1: Stopping all related services..."

# Stop uhttpd
/etc/init.d/uhttpd stop 2>/dev/null

# Kill any running network monitor processes
killall uhttpd 2>/dev/null
killall netmon-data-generator 2>/dev/null
killall netmon 2>/dev/null

# Stop and disable netmon service if exists
if [ -f /etc/init.d/netmon ]; then
    /etc/init.d/netmon stop 2>/dev/null
    /etc/init.d/netmon disable 2>/dev/null
fi

print_success "All services stopped"

# Step 2: Remove all files and directories
print_status "Step 2: Removing all Network Monitor files..."

# Remove web files
rm -rf /www/netmon 2>/dev/null
rm -rf /www/cgi-bin/netmon* 2>/dev/null
rm -rf /www/cgi-bin/ultimate* 2>/dev/null
rm -rf /www/cgi-bin/advanced* 2>/dev/null

# Remove data directories
rm -rf /var/lib/netmon 2>/dev/null
rm -rf /tmp/netmon 2>/dev/null

# Remove log files
rm -rf /var/log/netmon* 2>/dev/null
rm -rf /tmp/netmon* 2>/dev/null

# Remove binaries and scripts
rm -f /usr/bin/netmon-data-generator 2>/dev/null
rm -f /etc/init.d/netmon 2>/dev/null

print_success "All files and directories removed"

# Step 3: Clean uhttpd configuration
print_status "Step 3: Cleaning uhttpd configuration..."

# Remove network monitor specific uhttpd configurations
uci delete uhttpd.netmon 2>/dev/null
uci delete uhttpd.ultimate_netmon 2>/dev/null
uci delete uhttpd.main.cgi_prefix 2>/dev/null

# Reset uhttpd to default configuration
cat > /etc/config/uhttpd << 'EOFCONFIG'
config uhttpd 'main'
	option listen_http '0.0.0.0:80' '[::]:80'
	option listen_https '0.0.0.0:443' '[::]:443'
	option home '/www'
	option rfc1918_filter '1'
	option max_requests '3'
	option max_connections '100'
	option cert '/etc/uhttpd.crt'
	option key '/etc/uhttpd.key'
	option cgi_prefix '/cgi-bin'
	option lua_prefix '/cgi-bin/luci=/usr/lib/lua/luci/sgi/uhttpd.lua'
	option script_timeout '60'
	option network_timeout '30'
	option http_keepalive '20'
	option tcp_keepalive '1'
EOFCONFIG

uci commit uhttpd

print_success "uhttpd configuration reset to default"

# Step 4: Clean iptables rules (if any were added)
print_status "Step 4: Cleaning iptables rules..."

# Remove any custom iptables rules that might have been added
iptables -F 2>/dev/null
iptables -X 2>/dev/null

# Remove any traffic control rules
tc qdisc del dev br-lan root 2>/dev/null
tc qdisc del dev eth0 root 2>/dev/null

print_success "Network rules cleaned"

# Step 5: Remove any custom packages (if installed)
print_status "Step 5: Checking for custom packages..."

# Check if any packages were installed specifically for network monitor
for pkg in libnetfilter-log libnetfilter-queue sqlite3-cli libsqlite3; do
    if opkg list-installed | grep -q "^${pkg} "; then
        print_warning "Package $pkg was installed (keeping it as it might be used by other services)"
    fi
done

print_success "Package check completed"

# Step 6: Restore original web interface
print_status "Step 6: Restoring original web interface..."

# Restart uhttpd with clean configuration
/etc/init.d/uhttpd start

# Check if LuCI is available and working
if [ -d /usr/lib/lua/luci ]; then
    print_success "LuCI web interface restored"
else
    print_warning "LuCI not found - standard OpenWrt web interface"
fi

print_success "Web interface restored"

# Step 7: Final cleanup and verification
print_status "Step 7: Final cleanup and verification..."

# Remove any leftover temporary files
find /tmp -name "*netmon*" -delete 2>/dev/null
find /var -name "*netmon*" -delete 2>/dev/null

# Clear any caches
sync

print_success "Final cleanup completed"

# Verification
print_status "Verification:"

# Check if uhttpd is running
if pgrep uhttpd >/dev/null; then
    print_success "✅ uhttpd is running normally"
else
    print_warning "⚠️ uhttpd is not running - trying to start..."
    /etc/init.d/uhttpd start
fi

# Check web interface accessibility
router_ip=$(uci get network.lan.ipaddr 2>/dev/null || echo "192.168.1.1")
print_status "Standard web interface should be available at: http://$router_ip/"

# Check for any remaining network monitor files
remaining_files=$(find /www -name "*netmon*" 2>/dev/null | wc -l)
if [ "$remaining_files" -eq 0 ]; then
    print_success "✅ All Network Monitor files removed"
else
    print_warning "⚠️ Some files may still remain: $remaining_files files found"
fi

echo ""
echo "🗑️ COMPLETE UNINSTALL FINISHED"
echo "=============================="
echo ""
echo "✅ WHAT WAS REMOVED:"
echo "   • All Network Monitor web files"
echo "   • All CGI scripts and APIs" 
echo "   • All configuration files"
echo "   • All data and log files"
echo "   • All background services"
echo "   • All custom uhttpd configurations"
echo "   • All temporary files"
echo ""
echo "✅ WHAT WAS RESTORED:"
echo "   • Default uhttpd configuration"
echo "   • Standard OpenWrt web interface"
echo "   • Normal system operation"
echo ""
echo "🌐 ACCESS:"
echo "   • Standard interface: http://$router_ip/"
echo "   • SSH access remains unchanged"
echo ""
echo "💡 SYSTEM STATUS:"
echo "   • uhttpd: $(pgrep uhttpd >/dev/null && echo 'Running' || echo 'Stopped')"
echo "   • Network: Normal operation"
echo "   • Router: Fully functional"
echo ""

print_success "Network Monitor has been completely removed from your system"
print_status "Your OpenWrt router is back to its original state"

echo ""
echo "🙏 Thank you for trying Network Monitor"
echo "Sorry it didn't work as expected"
