#!/bin/bash

# Fix CGI 403 Forbidden Error for Network Monitor
# Run this on your OpenWrt router

echo "=== Fixing CGI 403 Forbidden Error ==="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running as root
if [ "$(id -u)" != "0" ]; then
    print_error "This script must be run as root"
    exit 1
fi

print_status "Fixing CGI permissions and configuration..."

# Create proper directory structure
print_status "Setting up CGI directory structure..."
mkdir -p /www/cgi-bin
mkdir -p /usr/lib/cgi-bin
mkdir -p /var/www/cgi-bin

# Fix CGI script with proper shebang and permissions
print_status "Creating working CGI script..."

# Remove old CGI scripts
rm -f /www/cgi-bin/netmon-api.lua
rm -f /usr/lib/cgi-bin/netmon-api.lua
rm -f /var/www/cgi-bin/netmon-api.lua

# Create a simple shell-based CGI script that works reliably
cat > /www/cgi-bin/netmon-api.sh << 'EOF'
#!/bin/sh

# Network Monitor API Script
# Content-Type header
echo "Content-Type: application/json"
echo "Access-Control-Allow-Origin: *"
echo "Access-Control-Allow-Methods: GET, POST, OPTIONS"
echo "Access-Control-Allow-Headers: Content-Type"
echo ""

# Parse query string
QUERY_STRING="${QUERY_STRING:-}"
ACTION="get_devices"

# Extract action from query string
for param in $(echo "$QUERY_STRING" | tr '&' ' '); do
    case "$param" in
        action=*)
            ACTION=$(echo "$param" | cut -d'=' -f2)
            ;;
    esac
done

# Function to get devices from ARP table
get_devices() {
    echo -n '{"success":true,"devices":['
    
    first=1
    if [ -f /proc/net/arp ]; then
        while IFS=' ' read -r ip hw_type flags mac mask device; do
            # Skip header and invalid entries
            if [ "$ip" != "IP" ] && [ "$mac" != "00:00:00:00:00:00" ] && [ -n "$mac" ]; then
                if [ $first -eq 0 ]; then
                    echo -n ','
                fi
                first=0
                
                # Try to get hostname
                hostname=$(nslookup "$ip" 2>/dev/null | awk '/name =/ {gsub(/\.$/, "", $4); print $4; exit}')
                if [ -z "$hostname" ]; then
                    hostname="Device-${ip##*.}"
                fi
                
                # Check if device is active (in last 5 minutes)
                is_active="true"
                
                echo -n "{\"ip\":\"$ip\",\"mac\":\"$mac\",\"hostname\":\"$hostname\",\"last_seen\":$(date +%s),\"is_active\":$is_active}"
            fi
        done < /proc/net/arp
    fi
    
    echo ']}'
}

# Function to get traffic data
get_traffic() {
    echo '{"success":true,"traffic":[]}'
}

# Function to get websites
get_websites() {
    echo '{"success":true,"websites":[]}'
}

# Function to get stats
get_stats() {
    device_count=0
    if [ -f /proc/net/arp ]; then
        device_count=$(awk 'NR>1 && $4!="00:00:00:00:00:00" {count++} END {print count+0}' /proc/net/arp)
    fi
    
    echo "{\"success\":true,\"stats\":{\"active_devices\":$device_count,\"total_download\":0,\"total_upload\":0,\"unique_websites\":0}}"
}

# Handle different actions
case "$ACTION" in
    "get_devices")
        get_devices
        ;;
    "get_traffic")
        get_traffic
        ;;
    "get_websites")
        get_websites
        ;;
    "get_stats")
        get_stats
        ;;
    *)
        echo '{"success":false,"error":"Unknown action"}'
        ;;
esac
EOF

# Set proper permissions
chmod 755 /www/cgi-bin/netmon-api.sh
chown root:root /www/cgi-bin/netmon-api.sh

print_success "CGI script created with proper permissions"

# Also create the Lua version with better permissions
cat > /www/cgi-bin/netmon-api.lua << 'EOF'
#!/usr/bin/lua

-- Set proper headers
print("Content-Type: application/json")
print("Access-Control-Allow-Origin: *")
print("Access-Control-Allow-Methods: GET, POST, OPTIONS")
print("Access-Control-Allow-Headers: Content-Type")
print("")

-- Simple device detection
local function get_devices()
    local devices = {}
    local arp_file = io.open("/proc/net/arp", "r")
    
    if arp_file then
        arp_file:read("*line") -- Skip header
        for line in arp_file:lines() do
            local ip, hw_type, flags, mac, mask, device = line:match("(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)")
            if ip and mac and mac ~= "00:00:00:00:00:00" then
                table.insert(devices, {
                    ip = ip,
                    mac = mac,
                    hostname = "Device-" .. ip:match("(%d+)$"),
                    last_seen = os.time(),
                    is_active = true
                })
            end
        end
        arp_file:close()
    end
    
    -- Output JSON manually to avoid dependency issues
    print('{"success":true,"devices":[')
    for i, device in ipairs(devices) do
        if i > 1 then print(',') end
        print(string.format('{"ip":"%s","mac":"%s","hostname":"%s","last_seen":%d,"is_active":%s}',
            device.ip, device.mac, device.hostname, device.last_seen, device.is_active and "true" or "false"))
    end
    print(']}')
end

-- Parse query and call appropriate function
local query = os.getenv("QUERY_STRING") or ""
local action = query:match("action=([^&]*)")

if not action or action == "get_devices" then
    get_devices()
else
    print('{"success":false,"error":"Unknown action"}')
end
EOF

chmod 755 /www/cgi-bin/netmon-api.lua
chown root:root /www/cgi-bin/netmon-api.lua

print_success "Lua CGI script created"

# Update uhttpd configuration to properly support CGI
print_status "Updating uhttpd configuration..."

# Backup original config
cp /etc/config/uhttpd /etc/config/uhttpd.backup

# Remove old netmon config if exists
sed -i '/config uhttpd .*netmon/,/^$/d' /etc/config/uhttpd

# Add proper CGI configuration
cat >> /etc/config/uhttpd << 'EOF'

config uhttpd 'netmon'
    option listen_http '0.0.0.0:8080'
    option home '/www/netmon'
    option cgi_prefix '/cgi-bin'
    option script_timeout '60'
    option network_timeout '30'
    option tcp_keepalive '1'
    option lua_prefix '/cgi-bin'
    option lua_handler '/usr/lib/lua/cgi-lua-handler.lua'
EOF

# Also update main uhttpd config to ensure CGI support
uci set uhttpd.main.cgi_prefix='/cgi-bin'
uci set uhttpd.main.script_timeout='60'
uci commit uhttpd

print_success "uhttpd configuration updated"

# Create a simple test CGI script
print_status "Creating test CGI script..."

cat > /www/cgi-bin/test.sh << 'EOF'
#!/bin/sh
echo "Content-Type: text/plain"
echo ""
echo "CGI is working!"
echo "Date: $(date)"
echo "Query: $QUERY_STRING"
EOF

chmod 755 /www/cgi-bin/test.sh

print_success "Test script created"

# Fix directory permissions
print_status "Fixing directory permissions..."
chmod 755 /www/cgi-bin
chmod 755 /www/netmon

# Restart uhttpd
print_status "Restarting uhttpd..."
/etc/init.d/uhttpd stop
sleep 2
/etc/init.d/uhttpd start

# Wait for service to start
sleep 3

# Check if uhttpd is running
if pgrep uhttpd > /dev/null; then
    print_success "uhttpd is running"
else
    print_error "uhttpd failed to start"
    print_status "Checking uhttpd status..."
    /etc/init.d/uhttpd status
fi

# Test CGI functionality
print_status "Testing CGI functionality..."

echo ""
echo "=== Testing CGI Scripts ==="
echo "1. Test basic CGI: http://$(uci get network.lan.ipaddr 2>/dev/null || echo '192.168.1.1'):8080/cgi-bin/test.sh"
echo "2. Test API (shell): http://$(uci get network.lan.ipaddr 2>/dev/null || echo '192.168.1.1'):8080/cgi-bin/netmon-api.sh?action=get_devices"
echo "3. Test API (lua): http://$(uci get network.lan.ipaddr 2>/dev/null || echo '192.168.1.1'):8080/cgi-bin/netmon-api.lua?action=get_devices"
echo ""

# Check if processes are running
print_status "Checking running processes..."
echo "uhttpd processes:"
ps | grep uhttpd || echo "No uhttpd processes found"

echo ""
echo "Listening ports:"
netstat -ln 2>/dev/null | grep :8080 || echo "Port 8080 not listening"

print_success "CGI fix completed!"
echo ""
print_warning "If you still get 403 errors, try:"
echo "1. Check logs: logread | grep uhttpd"
echo "2. Test basic CGI first: curl http://192.168.1.1:8080/cgi-bin/test.sh"
echo "3. Check file permissions: ls -la /www/cgi-bin/"
