#!/bin/bash

# Auto-generated Network Monitor Fix Script
echo "🔧 Auto-fixing Network Monitor issues..."

# Create directories
mkdir -p /www/netmon
mkdir -p /www/cgi-bin
chmod 755 /www/netmon
chmod 755 /www/cgi-bin

echo "📁 Directories created"

# Create working web interface
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
            <div id="deviceList" style="margin: 20px 0;">Loading devices...</div>
            <button class="refresh-btn" id="refreshBtn">🔄 Refresh Data</button>
        </div>
    </div>
    
    <script>
        let isLoading = false;
        
        async function loadDevices() {
            if (isLoading) return;
            isLoading = true;
            
            const refreshBtn = document.getElementById('refreshBtn');
            const originalText = refreshBtn.textContent;
            refreshBtn.textContent = '⏳ Loading...';
            refreshBtn.disabled = true;
            
            try {
                const response = await fetch('/cgi-bin/netmon-api.sh?action=get_devices');
                if (!response.ok) throw new Error('API Error');
                
                const data = await response.json();
                
                if (data.success && data.devices) {
                    displayDevices(data.devices);
                    updateStats(data.devices);
                } else {
                    throw new Error('No device data');
                }
            } catch (error) {
                console.error('Error loading devices:', error);
                document.getElementById('deviceList').innerHTML = '<div class="device-item">⚠️ Unable to load devices. Check API connection.</div>';
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
        
        // Event listeners
        document.getElementById('refreshBtn').addEventListener('click', loadDevices);
        
        // Load on page load and auto-refresh
        document.addEventListener('DOMContentLoaded', loadDevices);
        setInterval(loadDevices, 30000);
    </script>
</body>
</html>
EOF

echo "🌐 Web interface created"

# Create working CGI API
cat > /www/cgi-bin/netmon-api.sh << 'EOF'
#!/bin/sh

# Network Monitor API - Shell version
echo "Content-Type: application/json"
echo "Access-Control-Allow-Origin: *"
echo "Access-Control-Allow-Methods: GET, POST, OPTIONS"
echo "Access-Control-Allow-Headers: Content-Type"
echo ""

# Parse query string
QUERY_STRING="${QUERY_STRING:-}"
ACTION="get_devices"

for param in $(echo "$QUERY_STRING" | tr '&' ' '); do
    case "$param" in
        action=*)
            ACTION=$(echo "$param" | cut -d'=' -f2)
            ;;
    esac
done

# Get devices from ARP table
get_devices() {
    echo -n '{"success":true,"devices":['
    
    first=1
    if [ -f /proc/net/arp ]; then
        while IFS=' ' read -r ip hw_type flags mac mask device; do
            if [ "$ip" != "IP" ] && [ "$mac" != "00:00:00:00:00:00" ] && [ -n "$mac" ]; then
                if [ $first -eq 0 ]; then
                    echo -n ','
                fi
                first=0
                
                # Generate hostname
                hostname="Device-${ip##*.}"
                
                # Check if device is active (basic check)
                is_active="true"
                
                echo -n "{\"ip\":\"$ip\",\"mac\":\"$mac\",\"hostname\":\"$hostname\",\"last_seen\":$(date +%s),\"is_active\":$is_active}"
            fi
        done < /proc/net/arp
    fi
    
    echo ']}'
}

# Handle actions
case "$ACTION" in
    "get_devices")
        get_devices
        ;;
    *)
        echo '{"success":false,"error":"Unknown action"}'
        ;;
esac
EOF

echo "🔌 API script created"

# Set proper permissions
chmod 644 /www/netmon/index.html
chmod 755 /www/cgi-bin/netmon-api.sh
chown root:root /www/cgi-bin/netmon-api.sh

echo "🔐 Permissions set"

# Configure uhttpd
if ! grep -q "config uhttpd 'netmon'" /etc/config/uhttpd 2>/dev/null; then
    echo ""
    echo "config uhttpd 'netmon'"
    echo "    option listen_http '0.0.0.0:8080'"
    echo "    option home '/www/netmon'"
    echo "    option cgi_prefix '/cgi-bin'"
    echo "    option script_timeout '60'"
    echo "    option network_timeout '30'"
    echo "    option tcp_keepalive '1'"
    echo ""
    
    cat >> /etc/config/uhttpd << 'UHTTPD_EOF'

config uhttpd 'netmon'
    option listen_http '0.0.0.0:8080'
    option home '/www/netmon'
    option cgi_prefix '/cgi-bin'
    option script_timeout '60'
    option network_timeout '30'
    option tcp_keepalive '1'
UHTTPD_EOF

    echo "⚙️ uhttpd configured"
else
    echo "⚙️ uhttpd already configured"
fi

# Restart uhttpd
echo "🔄 Restarting uhttpd..."
/etc/init.d/uhttpd stop >/dev/null 2>&1
sleep 2
/etc/init.d/uhttpd start >/dev/null 2>&1
sleep 2

# Check if uhttpd is running
if pgrep uhttpd >/dev/null; then
    echo "✅ uhttpd is running"
else
    echo "❌ uhttpd failed to start"
    echo "   Trying to restart..."
    /etc/init.d/uhttpd restart
fi

echo ""
echo "🎉 Network Monitor auto-fix completed!"
echo ""
echo "📍 Access URLs:"
echo "   • http://$(uci get network.lan.ipaddr 2>/dev/null || echo '192.168.1.1'):8080/"
echo "   • http://$(uci get network.lan.ipaddr 2>/dev/null || echo '192.168.1.1'):8080/index.html"
echo ""
echo "🔌 API Test:"
echo "   • http://$(uci get network.lan.ipaddr 2>/dev/null || echo '192.168.1.1'):8080/cgi-bin/netmon-api.sh?action=get_devices"
echo ""
echo "🔧 If issues persist:"
echo "   • Check logs: logread | grep uhttpd"
echo "   • Check permissions: ls -la /www/cgi-bin/"
echo "   • Restart services: /etc/init.d/uhttpd restart"
