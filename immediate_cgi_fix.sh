#!/bin/bash

# Immediate CGI Fix for Network Monitor
# This script fixes the persistent 404 error for CGI scripts

echo "🔧 Immediate CGI Fix for Network Monitor"
echo "==============================================="

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

print_status "Diagnosing CGI 404 issue..."

# Check current uhttpd configuration
print_status "Checking uhttpd configuration..."
echo "Current uhttpd config:"
cat /etc/config/uhttpd

echo ""
print_status "Checking CGI directory and files..."
ls -la /www/cgi-bin/ 2>/dev/null || echo "CGI directory not found"

# Stop uhttpd completely
print_status "Stopping uhttpd completely..."
killall uhttpd 2>/dev/null
/etc/init.d/uhttpd stop 2>/dev/null
sleep 3

# Remove any existing netmon configuration
print_status "Cleaning uhttpd configuration..."
sed -i '/config uhttpd.*netmon/,/^$/d' /etc/config/uhttpd

# Ensure CGI directory exists with proper permissions
print_status "Setting up CGI directory..."
mkdir -p /www/cgi-bin
chmod 755 /www/cgi-bin

# Create the API script with proper shebang and permissions
print_status "Creating CGI API script..."
cat > /www/cgi-bin/netmon-api.sh << 'EOF'
#!/bin/sh

# Network Monitor API - Shell version
echo "Content-Type: application/json"
echo "Access-Control-Allow-Origin: *"
echo "Access-Control-Allow-Methods: GET, POST, OPTIONS"
echo "Access-Control-Allow-Headers: Content-Type"
echo ""

# Simple device detection from ARP table
echo -n '{"success":true,"devices":['

first=1
if [ -f /proc/net/arp ]; then
    while read -r ip hw_type flags mac mask device; do
        # Skip header and invalid entries
        if [ "$ip" != "IP" ] && [ "$mac" != "00:00:00:00:00:00" ] && [ -n "$mac" ] && [ "$ip" != "" ]; then
            if [ $first -eq 0 ]; then
                echo -n ','
            fi
            first=0
            
            # Generate hostname
            hostname="Device-${ip##*.}"
            
            # Current timestamp
            timestamp=$(date +%s)
            
            echo -n "{\"ip\":\"$ip\",\"mac\":\"$mac\",\"hostname\":\"$hostname\",\"last_seen\":$timestamp,\"is_active\":true}"
        fi
    done < /proc/net/arp
fi

echo ']}'
EOF

# Set proper permissions
chmod 755 /www/cgi-bin/netmon-api.sh
chown root:root /www/cgi-bin/netmon-api.sh

print_success "CGI script created and permissions set"

# Create a test CGI script
cat > /www/cgi-bin/test.sh << 'EOF'
#!/bin/sh
echo "Content-Type: text/plain"
echo ""
echo "CGI Test Successful!"
echo "Current time: $(date)"
echo "Query string: $QUERY_STRING"
echo "Script path: $SCRIPT_NAME"
EOF

chmod 755 /www/cgi-bin/test.sh

# Configure uhttpd properly for CGI
print_status "Configuring uhttpd for CGI..."

# Update main uhttpd config to ensure CGI support
uci set uhttpd.main.cgi_prefix='/cgi-bin'
uci set uhttpd.main.script_timeout='60'
uci set uhttpd.main.network_timeout='30'
uci commit uhttpd

# Add netmon-specific configuration
cat >> /etc/config/uhttpd << 'EOF'

config uhttpd 'netmon'
    option listen_http '0.0.0.0:8080'
    option home '/www/netmon'
    option cgi_prefix '/cgi-bin'
    option script_timeout '60'
    option network_timeout '30'
    option tcp_keepalive '1'
    option max_requests '100'
    option max_connections '100'
EOF

print_success "uhttpd configuration updated"

# Start uhttpd step by step
print_status "Starting uhttpd services..."

# Start main uhttpd first
/etc/init.d/uhttpd start
sleep 2

# Check if main uhttpd is running
if pgrep uhttpd >/dev/null; then
    print_success "Main uhttpd started successfully"
else
    print_error "Main uhttpd failed to start"
    # Try to start manually
    uhttpd -f -h /www -r OpenWrt -x /cgi-bin -t 60 -T 30 -k 20 -A 1 -n 3 -N 200 -R -p 80 &
    sleep 2
fi

# Start netmon uhttpd instance
print_status "Starting netmon uhttpd instance..."
uhttpd -f -h /www/netmon -r "Network Monitor" -x /cgi-bin -t 60 -T 30 -p 8080 &
sleep 2

print_success "uhttpd instances started"

# Verify CGI functionality
print_status "Testing CGI functionality..."

echo ""
echo "=== CGI Test Results ==="

# Test if CGI directory is accessible
if curl -s "http://localhost:8080/cgi-bin/test.sh" >/dev/null 2>&1; then
    print_success "CGI test script accessible"
else
    print_warning "CGI test script not accessible via curl"
fi

# Test API script
if curl -s "http://localhost:8080/cgi-bin/netmon-api.sh?action=get_devices" | grep -q "success"; then
    print_success "API script working"
else
    print_warning "API script not working via curl"
fi

# Show running processes
print_status "Checking running processes..."
echo "uhttpd processes:"
ps | grep uhttpd | grep -v grep

echo ""
echo "Listening ports:"
netstat -ln 2>/dev/null | grep :8080 || echo "Port 8080 not found in netstat"

# Alternative approach - use socat if uhttpd CGI doesn't work
print_status "Setting up alternative CGI server if needed..."

# Create a simple HTTP server script that handles CGI
cat > /usr/bin/netmon-server.sh << 'EOF'
#!/bin/sh

# Simple HTTP server for Network Monitor
PORT=8081

while true; do
    echo "HTTP/1.1 200 OK"
    echo "Content-Type: application/json"
    echo "Access-Control-Allow-Origin: *"
    echo ""
    
    # Get devices from ARP
    echo -n '{"success":true,"devices":['
    first=1
    if [ -f /proc/net/arp ]; then
        while read -r ip hw_type flags mac mask device; do
            if [ "$ip" != "IP" ] && [ "$mac" != "00:00:00:00:00:00" ] && [ -n "$mac" ]; then
                if [ $first -eq 0 ]; then echo -n ','; fi
                first=0
                hostname="Device-${ip##*.}"
                echo -n "{\"ip\":\"$ip\",\"mac\":\"$mac\",\"hostname\":\"$hostname\",\"last_seen\":$(date +%s),\"is_active\":true}"
            fi
        done < /proc/net/arp
    fi
    echo ']}'
done
EOF

chmod +x /usr/bin/netmon-server.sh

# Create updated web interface that tries multiple API endpoints
print_status "Updating web interface with fallback options..."

cat > /www/netmon/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Network Monitor - OpenWrt</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: linear-gradient(135deg, #667eea, #764ba2); min-height: 100vh; padding: 20px; }
        .container { max-width: 1200px; margin: 0 auto; }
        .header { background: rgba(255, 255, 255, 0.95); border-radius: 15px; padding: 30px; margin-bottom: 30px; text-align: center; box-shadow: 0 8px 32px rgba(0,0,0,0.1); }
        .header h1 { color: #4a5568; font-size: 2.5rem; margin-bottom: 10px; }
        .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .stat-card { background: rgba(255, 255, 255, 0.95); border-radius: 15px; padding: 25px; text-align: center; box-shadow: 0 8px 32px rgba(0,0,0,0.1); transition: transform 0.3s; }
        .stat-card:hover { transform: translateY(-5px); }
        .stat-icon { font-size: 3rem; margin-bottom: 15px; }
        .stat-number { font-size: 2rem; font-weight: bold; color: #2d3748; margin-bottom: 5px; }
        .stat-label { color: #4a5568; font-weight: 600; }
        .devices { background: rgba(255, 255, 255, 0.95); border-radius: 15px; padding: 30px; box-shadow: 0 8px 32px rgba(0,0,0,0.1); }
        .device-item { padding: 15px 0; border-bottom: 1px solid #e2e8f0; display: flex; justify-content: space-between; align-items: center; }
        .device-item:last-child { border-bottom: none; }
        .device-info h4 { color: #2d3748; margin-bottom: 5px; }
        .device-info p { color: #718096; font-size: 0.9rem; }
        .status-online { color: #16a34a; font-weight: bold; }
        .status-offline { color: #dc2626; font-weight: bold; }
        .refresh-btn { background: linear-gradient(135deg, #667eea, #764ba2); color: white; border: none; padding: 12px 25px; border-radius: 8px; cursor: pointer; font-weight: 600; margin-top: 20px; }
        .refresh-btn:hover { transform: translateY(-2px); }
        .refresh-btn:disabled { opacity: 0.6; }
        .status-message { padding: 10px; border-radius: 8px; margin: 10px 0; }
        .status-error { background: #fed7d7; color: #742a2a; }
        .status-success { background: #c6f6d5; color: #22543d; }
        .status-info { background: #bee3f8; color: #2a4365; }
        @media (max-width: 768px) { .stats { grid-template-columns: 1fr; } .device-item { flex-direction: column; align-items: flex-start; gap: 10px; } }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🌐 Network Monitor</h1>
            <p>Real-time network monitoring for OpenWrt</p>
        </div>
        
        <div class="stats">
            <div class="stat-card">
                <div class="stat-icon">📱</div>
                <div class="stat-number" id="deviceCount">0</div>
                <div class="stat-label">Connected Devices</div>
            </div>
            <div class="stat-card">
                <div class="stat-icon">⬇️</div>
                <div class="stat-number" id="totalDownload">0 MB</div>
                <div class="stat-label">Total Download</div>
            </div>
            <div class="stat-card">
                <div class="stat-icon">⬆️</div>
                <div class="stat-number" id="totalUpload">0 MB</div>
                <div class="stat-label">Total Upload</div>
            </div>
            <div class="stat-card">
                <div class="stat-icon">🌍</div>
                <div class="stat-number" id="websiteCount">0</div>
                <div class="stat-label">Websites Visited</div>
            </div>
        </div>
        
        <div class="devices">
            <h3>📋 Connected Devices</h3>
            <div id="statusMessage"></div>
            <div id="deviceList" style="margin: 20px 0;">Loading devices...</div>
            <button class="refresh-btn" id="refreshBtn">🔄 Refresh Data</button>
        </div>
    </div>
    
    <script>
        let isLoading = false;
        let currentApiEndpoint = null;
        
        // List of API endpoints to try
        const apiEndpoints = [
            '/cgi-bin/netmon-api.sh?action=get_devices',
            'http://192.168.1.1/cgi-bin/netmon-api.sh?action=get_devices',
            'http://192.168.1.1:80/cgi-bin/netmon-api.sh?action=get_devices'
        ];
        
        function showStatus(message, type = 'info') {
            const statusDiv = document.getElementById('statusMessage');
            statusDiv.innerHTML = `<div class="status-${type}">${message}</div>`;
        }
        
        async function tryApiEndpoint(endpoint) {
            try {
                const response = await fetch(endpoint);
                if (!response.ok) throw new Error(`HTTP ${response.status}`);
                
                const text = await response.text();
                const data = JSON.parse(text);
                
                if (data.success) {
                    currentApiEndpoint = endpoint;
                    showStatus(`✅ API working: ${endpoint}`, 'success');
                    return data;
                } else {
                    throw new Error('API returned success: false');
                }
            } catch (error) {
                console.log(`API endpoint ${endpoint} failed:`, error.message);
                return null;
            }
        }
        
        async function loadDevices() {
            if (isLoading) return;
            isLoading = true;
            
            const refreshBtn = document.getElementById('refreshBtn');
            const originalText = refreshBtn.textContent;
            refreshBtn.textContent = '⏳ Loading...';
            refreshBtn.disabled = true;
            
            try {
                let data = null;
                
                // Try current working endpoint first
                if (currentApiEndpoint) {
                    data = await tryApiEndpoint(currentApiEndpoint);
                }
                
                // If current endpoint fails, try all endpoints
                if (!data) {
                    showStatus('🔍 Searching for working API endpoint...', 'info');
                    
                    for (const endpoint of apiEndpoints) {
                        data = await tryApiEndpoint(endpoint);
                        if (data) break;
                    }
                }
                
                if (data && data.devices) {
                    displayDevices(data.devices);
                    updateStats(data.devices);
                    
                    if (!currentApiEndpoint) {
                        showStatus('⚠️ Using fallback API endpoint', 'info');
                    }
                } else {
                    throw new Error('All API endpoints failed');
                }
                
            } catch (error) {
                console.error('Error loading devices:', error);
                showStatus('❌ API connection failed. Showing demo data.', 'error');
                showDemoData();
            } finally {
                refreshBtn.textContent = originalText;
                refreshBtn.disabled = false;
                isLoading = false;
            }
        }
        
        function displayDevices(devices) {
            const deviceList = document.getElementById('deviceList');
            
            if (devices.length === 0) {
                deviceList.innerHTML = '<div class="device-item">No devices found</div>';
                return;
            }
            
            deviceList.innerHTML = devices.map(device => `
                <div class="device-item">
                    <div class="device-info">
                        <h4>${device.hostname || 'Unknown Device'}</h4>
                        <p>IP: ${device.ip} | MAC: ${device.mac || 'Unknown'}</p>
                        <p>Last seen: ${new Date(device.last_seen * 1000).toLocaleString()}</p>
                    </div>
                    <div class="${device.is_active ? 'status-online' : 'status-offline'}">
                        ${device.is_active ? 'Online' : 'Offline'}
                    </div>
                </div>
            `).join('');
        }
        
        function updateStats(devices) {
            const activeDevices = devices.filter(d => d.is_active).length;
            document.getElementById('deviceCount').textContent = activeDevices;
        }
        
        function showDemoData() {
            const demoDevices = [
                {
                    ip: '192.168.1.1',
                    mac: '00:11:22:33:44:55',
                    hostname: 'Router',
                    last_seen: Math.floor(Date.now() / 1000),
                    is_active: true
                },
                {
                    ip: '192.168.1.100',
                    mac: '00:11:22:33:44:56',
                    hostname: 'Demo Device',
                    last_seen: Math.floor(Date.now() / 1000) - 120,
                    is_active: true
                }
            ];
            
            displayDevices(demoDevices);
            updateStats(demoDevices);
        }
        
        // Event listeners
        document.getElementById('refreshBtn').addEventListener('click', loadDevices);
        
        // Load on page load and auto-refresh
        document.addEventListener('DOMContentLoaded', loadDevices);
        setInterval(loadDevices, 30000);
    </script>
</body>
</html>
EOF

print_success "Updated web interface with multiple API endpoint support"

print_status "Final verification..."

# Test final configuration
echo ""
echo "=== Final Test Results ==="

# Test web interface
if curl -s "http://localhost:8080/" | grep -q "Network Monitor"; then
    print_success "Web interface accessible"
else
    print_warning "Web interface test failed"
fi

# Show final URLs
echo ""
print_success "Immediate fix completed!"
echo ""
echo "📍 Try these URLs:"
echo "   • http://192.168.1.1:8080/"
echo "   • http://192.168.1.1:8080/index.html"
echo ""
echo "🔌 Test CGI directly:"
echo "   • http://192.168.1.1:8080/cgi-bin/test.sh"
echo "   • http://192.168.1.1:8080/cgi-bin/netmon-api.sh?action=get_devices"
echo ""
echo "🔧 If still not working:"
echo "   • Run: logread | grep uhttpd"
echo "   • Run: ps | grep uhttpd"
echo "   • Run: netstat -ln | grep 8080"
echo "   • Try: /etc/init.d/uhttpd restart"

print_warning "The web interface now includes fallback options and will try multiple API endpoints automatically."
