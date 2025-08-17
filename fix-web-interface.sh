#!/bin/bash

# Quick fix script for Network Monitor web interface
# Run this on your OpenWrt router

echo "=== Network Monitor Web Interface Fix ==="
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

print_status "Checking current web interface setup..."

# Create web directory structure
print_status "Creating web directories..."
mkdir -p /www/netmon
mkdir -p /www/cgi-bin
chmod 755 /www/netmon
chmod 755 /www/cgi-bin

# Create main web interface files directly
print_status "Creating web interface files..."

# Create index.html
cat > /www/netmon/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Network Monitor</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            color: #333;
            padding: 20px;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        
        .header {
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            border-radius: 15px;
            padding: 30px;
            margin-bottom: 30px;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
            text-align: center;
        }
        
        .header h1 {
            color: #4a5568;
            font-size: 2.5rem;
            margin-bottom: 10px;
        }
        
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        
        .stat-card {
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            border-radius: 15px;
            padding: 25px;
            text-align: center;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
            transition: transform 0.3s ease;
        }
        
        .stat-card:hover {
            transform: translateY(-5px);
        }
        
        .stat-icon {
            font-size: 3rem;
            color: #667eea;
            margin-bottom: 15px;
        }
        
        .stat-number {
            font-size: 2rem;
            font-weight: bold;
            color: #2d3748;
            margin-bottom: 5px;
        }
        
        .stat-label {
            color: #4a5568;
            font-weight: 600;
        }
        
        .card {
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            border-radius: 15px;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
            overflow: hidden;
            margin-bottom: 30px;
        }
        
        .card-header {
            padding: 25px 30px;
            border-bottom: 1px solid #e2e8f0;
            background: #f8f9fa;
        }
        
        .card-header h3 {
            color: #4a5568;
            font-size: 1.25rem;
            font-weight: 700;
        }
        
        .card-content {
            padding: 30px;
        }
        
        .device-list {
            list-style: none;
        }
        
        .device-item {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 15px 0;
            border-bottom: 1px solid #e2e8f0;
        }
        
        .device-item:last-child {
            border-bottom: none;
        }
        
        .device-info h4 {
            color: #2d3748;
            margin-bottom: 5px;
        }
        
        .device-info p {
            color: #718096;
            font-size: 0.9rem;
        }
        
        .device-status {
            padding: 5px 15px;
            border-radius: 20px;
            font-size: 0.8rem;
            font-weight: 600;
            text-transform: uppercase;
        }
        
        .status-online {
            background: #c6f6d5;
            color: #22543d;
        }
        
        .status-offline {
            background: #fed7d7;
            color: #742a2a;
        }
        
        .refresh-btn {
            background: linear-gradient(135deg, #667eea, #764ba2);
            color: white;
            border: none;
            padding: 12px 25px;
            border-radius: 8px;
            cursor: pointer;
            font-weight: 600;
            margin-top: 20px;
            transition: transform 0.3s ease;
        }
        
        .refresh-btn:hover {
            transform: translateY(-2px);
        }
        
        .loading {
            display: inline-block;
            width: 20px;
            height: 20px;
            border: 3px solid #f3f3f3;
            border-top: 3px solid #667eea;
            border-radius: 50%;
            animation: spin 1s linear infinite;
        }
        
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        
        .error-message {
            background: #fed7d7;
            color: #742a2a;
            padding: 15px;
            border-radius: 8px;
            margin: 20px 0;
        }
        
        @media (max-width: 768px) {
            .stats-grid {
                grid-template-columns: 1fr;
            }
            
            .device-item {
                flex-direction: column;
                align-items: flex-start;
                gap: 10px;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🌐 Network Monitor</h1>
            <p>Real-time network monitoring for OpenWrt</p>
        </div>
        
        <div class="stats-grid">
            <div class="stat-card">
                <div class="stat-icon">📱</div>
                <div class="stat-number" id="deviceCount">-</div>
                <div class="stat-label">Connected Devices</div>
            </div>
            
            <div class="stat-card">
                <div class="stat-icon">⬇️</div>
                <div class="stat-number" id="totalDownload">-</div>
                <div class="stat-label">Total Download</div>
            </div>
            
            <div class="stat-card">
                <div class="stat-icon">⬆️</div>
                <div class="stat-number" id="totalUpload">-</div>
                <div class="stat-label">Total Upload</div>
            </div>
            
            <div class="stat-card">
                <div class="stat-icon">🌍</div>
                <div class="stat-number" id="websiteCount">-</div>
                <div class="stat-label">Websites Visited</div>
            </div>
        </div>
        
        <div class="card">
            <div class="card-header">
                <h3>📋 Connected Devices</h3>
            </div>
            <div class="card-content">
                <ul class="device-list" id="deviceList">
                    <li class="device-item">
                        <div class="loading"></div>
                        <span style="margin-left: 10px;">Loading devices...</span>
                    </li>
                </ul>
                <button class="refresh-btn" onclick="loadData()">
                    🔄 Refresh Data
                </button>
            </div>
        </div>
    </div>
    
    <script>
        // Load data function
        async function loadData() {
            try {
                const response = await fetch('/cgi-bin/netmon-api.lua?action=get_devices');
                const data = await response.json();
                
                if (data.success) {
                    updateDeviceList(data.devices || []);
                    updateStats(data.devices || []);
                } else {
                    showError('Failed to load device data: ' + (data.error || 'Unknown error'));
                }
            } catch (error) {
                console.error('Error loading data:', error);
                showDemoData();
            }
        }
        
        // Update device list
        function updateDeviceList(devices) {
            const deviceList = document.getElementById('deviceList');
            deviceList.innerHTML = '';
            
            if (devices.length === 0) {
                deviceList.innerHTML = '<li class="device-item">No devices found</li>';
                return;
            }
            
            devices.forEach(device => {
                const li = document.createElement('li');
                li.className = 'device-item';
                li.innerHTML = `
                    <div class="device-info">
                        <h4>${device.hostname || 'Unknown Device'}</h4>
                        <p>IP: ${device.ip} | MAC: ${device.mac || 'Unknown'}</p>
                        <p>Last seen: ${formatTime(device.last_seen)}</p>
                    </div>
                    <div class="device-status ${device.is_active ? 'status-online' : 'status-offline'}">
                        ${device.is_active ? 'Online' : 'Offline'}
                    </div>
                `;
                deviceList.appendChild(li);
            });
        }
        
        // Update statistics
        function updateStats(devices) {
            const activeDevices = devices.filter(d => d.is_active).length;
            document.getElementById('deviceCount').textContent = activeDevices;
            document.getElementById('totalDownload').textContent = '0 MB';
            document.getElementById('totalUpload').textContent = '0 MB';
            document.getElementById('websiteCount').textContent = '0';
        }
        
        // Show demo data if API fails
        function showDemoData() {
            const demoDevices = [
                {
                    ip: '192.168.1.100',
                    mac: '00:11:22:33:44:55',
                    hostname: 'Router',
                    last_seen: Math.floor(Date.now() / 1000),
                    is_active: true
                },
                {
                    ip: '192.168.1.101',
                    mac: '00:11:22:33:44:56',
                    hostname: 'Demo Device',
                    last_seen: Math.floor(Date.now() / 1000) - 300,
                    is_active: true
                }
            ];
            
            updateDeviceList(demoDevices);
            updateStats(demoDevices);
            
            showError('Using demo data - API connection failed');
        }
        
        // Show error message
        function showError(message) {
            const deviceList = document.getElementById('deviceList');
            const errorDiv = document.createElement('div');
            errorDiv.className = 'error-message';
            errorDiv.textContent = message;
            deviceList.parentNode.insertBefore(errorDiv, deviceList);
        }
        
        // Format timestamp
        function formatTime(timestamp) {
            if (!timestamp) return 'Never';
            const date = new Date(timestamp * 1000);
            return date.toLocaleString();
        }
        
        // Load data on page load
        document.addEventListener('DOMContentLoaded', loadData);
        
        // Auto-refresh every 30 seconds
        setInterval(loadData, 30000);
    </script>
</body>
</html>
EOF

# Create simple API script
cat > /www/cgi-bin/netmon-api.lua << 'EOF'
#!/usr/bin/lua

-- Simple Network Monitor API
local json = require "luci.json"

-- Set content type
print("Content-Type: application/json\n")

-- Parse query string
local query_string = os.getenv("QUERY_STRING") or ""
local action = "get_devices"

for param in query_string:gmatch("([^&]+)") do
    local key, value = param:match("([^=]+)=([^=]*)")
    if key == "action" then
        action = value
    end
end

-- Simple device detection from ARP table
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
                    hostname = ip, -- Use IP as hostname for now
                    last_seen = os.time(),
                    is_active = true
                })
            end
        end
        arp_file:close()
    end
    
    return { success = true, devices = devices }
end

-- Handle different actions
local result
if action == "get_devices" then
    result = get_devices()
else
    result = { success = false, error = "Unknown action" }
end

print(json.encode(result))
EOF

# Set proper permissions
chmod 644 /www/netmon/index.html
chmod 755 /www/cgi-bin/netmon-api.lua

print_success "Web interface files created"

# Configure uhttpd
print_status "Configuring uhttpd..."

# Check if netmon config already exists
if ! grep -q "config uhttpd 'netmon'" /etc/config/uhttpd 2>/dev/null; then
    cat >> /etc/config/uhttpd << 'EOF'

config uhttpd 'netmon'
    option listen_http '0.0.0.0:8080'
    option home '/www/netmon'
    option cgi_prefix '/cgi-bin'
    option script_timeout '60'
    option network_timeout '30'
    option tcp_keepalive '1'
    option error_page '/www/netmon/index.html'
EOF
    print_success "uhttpd configuration added"
else
    print_warning "uhttpd netmon configuration already exists"
fi

# Restart uhttpd
print_status "Restarting uhttpd..."
/etc/init.d/uhttpd restart

# Check if service is running
print_status "Checking uhttpd status..."
if /etc/init.d/uhttpd status > /dev/null 2>&1; then
    print_success "uhttpd is running"
else
    print_error "uhttpd is not running - trying to start..."
    /etc/init.d/uhttpd start
fi

# Check if port 8080 is listening
print_status "Checking if port 8080 is open..."
if netstat -ln 2>/dev/null | grep -q ":8080"; then
    print_success "Port 8080 is listening"
else
    print_warning "Port 8080 may not be listening"
fi

print_status "Testing web interface..."
echo ""
echo "=== Web Interface Test ==="
echo "1. Direct file access: http://$(uci get network.lan.ipaddr 2>/dev/null || echo '192.168.1.1'):8080/index.html"
echo "2. Main interface: http://$(uci get network.lan.ipaddr 2>/dev/null || echo '192.168.1.1'):8080/netmon/"
echo "3. Root path: http://$(uci get network.lan.ipaddr 2>/dev/null || echo '192.168.1.1'):8080/"
echo ""

print_success "Web interface fix completed!"
echo ""
echo "Please try accessing: http://$(uci get network.lan.ipaddr 2>/dev/null || echo '192.168.1.1'):8080/"
echo ""
echo "If you still see 'Not Found', try:"
echo "1. http://$(uci get network.lan.ipaddr 2>/dev/null || echo '192.168.1.1'):8080/index.html"
echo "2. Check uhttpd logs: logread | grep uhttpd"
echo "3. Restart uhttpd: /etc/init.d/uhttpd restart"
