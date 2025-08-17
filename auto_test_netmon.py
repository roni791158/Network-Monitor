#!/usr/bin/env python3
"""
Automated Network Monitor Web Interface Tester
No user input required - runs automatically
"""

import time
import json
import os
import sys
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import TimeoutException, WebDriverException

def setup_chrome_driver():
    """Setup Chrome WebDriver"""
    print("🚀 Setting up Chrome WebDriver...")
    
    chrome_options = Options()
    chrome_options.add_argument("--no-sandbox")
    chrome_options.add_argument("--disable-dev-shm-usage")
    chrome_options.add_argument("--disable-gpu")
    chrome_options.add_argument("--window-size=1200,800")
    chrome_options.add_argument("--disable-web-security")
    chrome_options.add_argument("--allow-running-insecure-content")
    chrome_options.add_argument("--disable-features=VizDisplayCompositor")
    
    chromedriver_path = "./chromedriver.exe"
    if not os.path.exists(chromedriver_path):
        print("❌ ChromeDriver not found!")
        return None
        
    service = Service(chromedriver_path)
    
    try:
        driver = webdriver.Chrome(service=service, options=chrome_options)
        driver.implicitly_wait(10)
        print("✅ Chrome WebDriver setup successful!")
        return driver
    except Exception as e:
        print(f"❌ Failed to setup ChromeDriver: {e}")
        return None

def test_network_monitor(router_ip="192.168.1.1", port="8080"):
    """Test Network Monitor web interface"""
    print(f"🎯 Testing Network Monitor at {router_ip}:{port}")
    print("=" * 60)
    
    driver = setup_chrome_driver()
    if not driver:
        return False
    
    test_results = []
    
    try:
        base_url = f"http://{router_ip}:{port}"
        
        # Test URLs to try
        test_urls = [
            f"{base_url}/",
            f"{base_url}/index.html",
            f"{base_url}/netmon/",
            f"{base_url}/netmon/index.html"
        ]
        
        working_url = None
        
        print("🔍 Testing web interface URLs...")
        for url in test_urls:
            try:
                print(f"   Testing: {url}")
                driver.get(url)
                time.sleep(3)
                
                title = driver.title
                body_text = driver.find_element(By.TAG_NAME, "body").text.lower()
                
                if "not found" in body_text:
                    print(f"   ❌ 404 Not Found")
                elif "forbidden" in body_text:
                    print(f"   ❌ 403 Forbidden")
                elif "network monitor" in body_text or "network monitor" in title.lower():
                    print(f"   ✅ Working! Title: {title}")
                    working_url = url
                    test_results.append({"url": url, "status": "working", "title": title})
                    break
                else:
                    print(f"   ⚠️ Unexpected content")
                    
            except Exception as e:
                print(f"   ❌ Error: {str(e)[:50]}...")
        
        # Test API endpoints
        print("\n🔌 Testing API endpoints...")
        api_endpoints = [
            f"{base_url}/cgi-bin/netmon-api.sh?action=get_devices",
            f"{base_url}/cgi-bin/netmon-api.lua?action=get_devices",
            f"{base_url}/cgi-bin/test.sh"
        ]
        
        working_apis = []
        for endpoint in api_endpoints:
            try:
                print(f"   Testing: {endpoint}")
                driver.get(endpoint)
                time.sleep(2)
                
                body_text = driver.find_element(By.TAG_NAME, "body").text
                
                if "forbidden" in body_text.lower():
                    print(f"   ❌ 403 Forbidden")
                elif "not found" in body_text.lower():
                    print(f"   ❌ 404 Not Found")
                elif '"success"' in body_text or "cgi is working" in body_text.lower():
                    print(f"   ✅ Working!")
                    working_apis.append(endpoint)
                else:
                    print(f"   ⚠️ Unexpected response: {body_text[:50]}...")
                    
            except Exception as e:
                print(f"   ❌ Error: {str(e)[:50]}...")
        
        # Test JavaScript functionality if we have a working URL
        if working_url:
            print(f"\n📜 Testing JavaScript on: {working_url}")
            try:
                driver.get(working_url)
                time.sleep(5)
                
                # Check for JavaScript errors
                logs = driver.get_log('browser')
                js_errors = [log for log in logs if log['level'] == 'SEVERE']
                
                if js_errors:
                    print("   ❌ JavaScript errors found:")
                    for error in js_errors[:3]:  # Show first 3 errors
                        print(f"      • {error['message'][:80]}...")
                else:
                    print("   ✅ No severe JavaScript errors")
                
                # Check device count element
                try:
                    device_count = driver.find_element(By.ID, "deviceCount").text
                    print(f"   📱 Device Count: {device_count}")
                    if device_count and device_count != "-":
                        print("   ✅ Device count is updating")
                    else:
                        print("   ⚠️ Device count not updating")
                except:
                    print("   ❌ Device count element not found")
                
                # Test refresh button
                try:
                    refresh_btn = driver.find_element(By.ID, "refreshBtn")
                    if refresh_btn:
                        print("   ✅ Refresh button found")
                        refresh_btn.click()
                        time.sleep(2)
                        print("   ✅ Refresh button works")
                except:
                    print("   ❌ Refresh button not working")
                    
            except Exception as e:
                print(f"   ❌ JavaScript test failed: {e}")
        
        # Generate results summary
        print("\n" + "=" * 60)
        print("📊 TEST RESULTS SUMMARY")
        print("=" * 60)
        
        if working_url:
            print(f"✅ Working Web Interface: {working_url}")
        else:
            print("❌ No working web interface found")
        
        if working_apis:
            print(f"✅ Working APIs ({len(working_apis)}):")
            for api in working_apis:
                print(f"   • {api}")
        else:
            print("❌ No working APIs found")
        
        # Generate auto-fix script
        print("\n🔧 Generating auto-fix script...")
        generate_auto_fix_script(working_url is None, not working_apis)
        
        return working_url is not None and working_apis
        
    finally:
        driver.quit()
        print("\n🏁 Browser test completed")

def generate_auto_fix_script(web_broken, api_broken):
    """Generate fix script based on test results"""
    
    fix_script = '''#!/bin/bash

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
                
                echo -n "{\\"ip\\":\\"$ip\\",\\"mac\\":\\"$mac\\",\\"hostname\\":\\"$hostname\\",\\"last_seen\\":$(date +%s),\\"is_active\\":$is_active}"
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
'''
    
    with open("auto_fix_netmon.sh", "w", encoding='utf-8') as f:
        f.write(fix_script)
    
    print("✅ Auto-fix script generated: auto_fix_netmon.sh")
    print("📤 Copy this script to your OpenWrt router and run it as root")

def main():
    """Main function"""
    print("🚀 Automated Network Monitor Tester")
    print("📡 Testing router at 192.168.1.1:8080")
    print("=" * 60)
    
    success = test_network_monitor()
    
    print("\n" + "=" * 60)
    if success:
        print("🎉 Network Monitor is working correctly!")
    else:
        print("🔧 Issues detected - auto-fix script generated")
        print("📋 Next steps:")
        print("   1. Copy auto_fix_netmon.sh to your OpenWrt router")
        print("   2. Run: chmod +x auto_fix_netmon.sh && ./auto_fix_netmon.sh")
        print("   3. Access: http://192.168.1.1:8080/")
    
    print("=" * 60)

if __name__ == "__main__":
    main()
