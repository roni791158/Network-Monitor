#!/usr/bin/env python3
"""
Network Monitor Web Interface Selenium Tester
Automatically tests and fixes web interface issues
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

class NetworkMonitorTester:
    def __init__(self, router_ip="192.168.1.1", port="8080"):
        self.router_ip = router_ip
        self.port = port
        self.base_url = f"http://{router_ip}:{port}"
        self.driver = None
        self.test_results = []
        
    def setup_driver(self):
        """Setup Chrome WebDriver with appropriate options"""
        print("🚀 Setting up Chrome WebDriver...")
        
        # Chrome options for better compatibility
        chrome_options = Options()
        chrome_options.add_argument("--no-sandbox")
        chrome_options.add_argument("--disable-dev-shm-usage")
        chrome_options.add_argument("--disable-gpu")
        chrome_options.add_argument("--window-size=1200,800")
        chrome_options.add_argument("--disable-web-security")
        chrome_options.add_argument("--allow-running-insecure-content")
        chrome_options.add_argument("--disable-features=VizDisplayCompositor")
        
        # ChromeDriver service
        chromedriver_path = "./chromedriver.exe"
        if not os.path.exists(chromedriver_path):
            print("❌ ChromeDriver not found! Please ensure chromedriver.exe is in the current directory.")
            return False
            
        service = Service(chromedriver_path)
        
        try:
            self.driver = webdriver.Chrome(service=service, options=chrome_options)
            self.driver.implicitly_wait(10)
            print("✅ Chrome WebDriver setup successful!")
            return True
        except Exception as e:
            print(f"❌ Failed to setup ChromeDriver: {e}")
            return False
    
    def test_main_page(self):
        """Test main page loading"""
        print(f"\n🔍 Testing main page: {self.base_url}")
        
        try:
            self.driver.get(self.base_url)
            time.sleep(3)
            
            # Check if page loaded
            title = self.driver.title
            print(f"📄 Page Title: {title}")
            
            # Check for common error messages
            body_text = self.driver.find_element(By.TAG_NAME, "body").text.lower()
            
            if "not found" in body_text:
                print("❌ 404 Not Found error detected")
                self.test_results.append({
                    "test": "main_page",
                    "status": "failed",
                    "error": "404 Not Found"
                })
                return False
            elif "forbidden" in body_text:
                print("❌ 403 Forbidden error detected")
                self.test_results.append({
                    "test": "main_page",
                    "status": "failed", 
                    "error": "403 Forbidden"
                })
                return False
            elif "network monitor" in body_text:
                print("✅ Network Monitor page loaded successfully!")
                self.test_results.append({
                    "test": "main_page",
                    "status": "passed"
                })
                return True
            else:
                print("⚠️ Unexpected page content")
                self.test_results.append({
                    "test": "main_page",
                    "status": "warning",
                    "error": "Unexpected content"
                })
                return False
                
        except Exception as e:
            print(f"❌ Error loading main page: {e}")
            self.test_results.append({
                "test": "main_page",
                "status": "failed",
                "error": str(e)
            })
            return False
    
    def test_alternative_urls(self):
        """Test alternative URL paths"""
        print("\n🔗 Testing alternative URLs...")
        
        urls_to_test = [
            f"{self.base_url}/",
            f"{self.base_url}/index.html",
            f"{self.base_url}/netmon/",
            f"{self.base_url}/netmon/index.html"
        ]
        
        successful_urls = []
        
        for url in urls_to_test:
            try:
                print(f"🔍 Testing: {url}")
                self.driver.get(url)
                time.sleep(2)
                
                body_text = self.driver.find_element(By.TAG_NAME, "body").text.lower()
                
                if "network monitor" in body_text and "not found" not in body_text:
                    print(f"✅ {url} - Working!")
                    successful_urls.append(url)
                else:
                    print(f"❌ {url} - Failed")
                    
            except Exception as e:
                print(f"❌ {url} - Error: {e}")
        
        if successful_urls:
            print(f"✅ Found {len(successful_urls)} working URLs:")
            for url in successful_urls:
                print(f"   • {url}")
            return successful_urls[0]  # Return first working URL
        else:
            print("❌ No working URLs found")
            return None
    
    def test_api_endpoints(self):
        """Test API endpoints"""
        print("\n🔌 Testing API endpoints...")
        
        api_endpoints = [
            f"{self.base_url}/cgi-bin/netmon-api.sh?action=get_devices",
            f"{self.base_url}/cgi-bin/netmon-api.lua?action=get_devices",
            f"{self.base_url}/cgi-bin/test.sh"
        ]
        
        working_apis = []
        
        for endpoint in api_endpoints:
            try:
                print(f"🔍 Testing API: {endpoint}")
                self.driver.get(endpoint)
                time.sleep(2)
                
                body_text = self.driver.find_element(By.TAG_NAME, "body").text
                
                if "forbidden" in body_text.lower():
                    print(f"❌ {endpoint} - 403 Forbidden")
                elif "not found" in body_text.lower():
                    print(f"❌ {endpoint} - 404 Not Found")
                elif "success" in body_text.lower() or "cgi is working" in body_text.lower():
                    print(f"✅ {endpoint} - Working!")
                    working_apis.append(endpoint)
                else:
                    print(f"⚠️ {endpoint} - Unexpected response")
                    
            except Exception as e:
                print(f"❌ {endpoint} - Error: {e}")
        
        return working_apis
    
    def test_javascript_functionality(self, working_url):
        """Test JavaScript functionality"""
        print("\n📜 Testing JavaScript functionality...")
        
        try:
            self.driver.get(working_url)
            time.sleep(5)  # Wait for page to fully load
            
            # Check for JavaScript errors in console
            logs = self.driver.get_log('browser')
            js_errors = [log for log in logs if log['level'] == 'SEVERE']
            
            if js_errors:
                print("❌ JavaScript errors found:")
                for error in js_errors:
                    print(f"   • {error['message']}")
                self.test_results.append({
                    "test": "javascript",
                    "status": "failed",
                    "errors": [error['message'] for error in js_errors]
                })
            else:
                print("✅ No severe JavaScript errors found")
                
            # Check if device count is being updated
            try:
                device_count_element = WebDriverWait(self.driver, 10).until(
                    EC.presence_of_element_located((By.ID, "deviceCount"))
                )
                device_count = device_count_element.text
                print(f"📱 Device Count: {device_count}")
                
                if device_count and device_count != "-":
                    print("✅ Device count is being updated")
                    self.test_results.append({
                        "test": "device_count",
                        "status": "passed",
                        "value": device_count
                    })
                else:
                    print("⚠️ Device count not updated (using fallback data)")
                    
            except TimeoutException:
                print("❌ Device count element not found")
                
            # Test refresh button
            try:
                refresh_btn = self.driver.find_element(By.ID, "refreshBtn")
                if refresh_btn:
                    print("✅ Refresh button found")
                    refresh_btn.click()
                    time.sleep(3)
                    print("✅ Refresh button clicked successfully")
                    
            except Exception as e:
                print(f"❌ Refresh button test failed: {e}")
                
        except Exception as e:
            print(f"❌ JavaScript test failed: {e}")
    
    def generate_fix_script(self):
        """Generate a fix script based on test results"""
        print("\n🔧 Generating fix script based on test results...")
        
        fix_script = """#!/bin/bash

# Auto-generated fix script for Network Monitor
echo "=== Auto-Fix Network Monitor Issues ==="

# Fix web directory and files
mkdir -p /www/netmon
mkdir -p /www/cgi-bin

# Create working web interface
cat > /www/netmon/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Network Monitor</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; }
        .header { background: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 20px; }
        .stat-card { background: white; padding: 20px; border-radius: 8px; text-align: center; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .stat-number { font-size: 2rem; font-weight: bold; color: #2563eb; }
        .devices { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .device-item { padding: 10px; border-bottom: 1px solid #eee; display: flex; justify-content: space-between; }
        .status-online { color: #16a34a; font-weight: bold; }
        .status-offline { color: #dc2626; font-weight: bold; }
        .refresh-btn { background: #2563eb; color: white; border: none; padding: 10px 20px; border-radius: 4px; cursor: pointer; }
        .refresh-btn:hover { background: #1d4ed8; }
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
                <div class="stat-number" id="deviceCount">0</div>
                <div>Connected Devices</div>
            </div>
            <div class="stat-card">
                <div class="stat-number" id="totalDownload">0 MB</div>
                <div>Total Download</div>
            </div>
            <div class="stat-card">
                <div class="stat-number" id="totalUpload">0 MB</div>
                <div>Total Upload</div>
            </div>
        </div>
        
        <div class="devices">
            <h3>Connected Devices</h3>
            <div id="deviceList">Loading...</div>
            <button class="refresh-btn" onclick="loadDevices()">🔄 Refresh</button>
        </div>
    </div>
    
    <script>
        async function loadDevices() {
            try {
                const response = await fetch('/cgi-bin/netmon-api.sh?action=get_devices');
                const data = await response.json();
                
                if (data.success && data.devices) {
                    displayDevices(data.devices);
                    document.getElementById('deviceCount').textContent = data.devices.filter(d => d.is_active).length;
                } else {
                    document.getElementById('deviceList').innerHTML = '<div class="device-item">No devices found or API error</div>';
                }
            } catch (error) {
                console.error('Error:', error);
                document.getElementById('deviceList').innerHTML = '<div class="device-item">Error loading devices</div>';
            }
        }
        
        function displayDevices(devices) {
            const deviceList = document.getElementById('deviceList');
            deviceList.innerHTML = '';
            
            devices.forEach(device => {
                const div = document.createElement('div');
                div.className = 'device-item';
                div.innerHTML = `
                    <span><strong>${device.hostname}</strong><br>IP: ${device.ip}<br>MAC: ${device.mac}</span>
                    <span class="${device.is_active ? 'status-online' : 'status-offline'}">
                        ${device.is_active ? 'Online' : 'Offline'}
                    </span>
                `;
                deviceList.appendChild(div);
            });
        }
        
        // Load devices on page load
        loadDevices();
        
        // Auto-refresh every 30 seconds
        setInterval(loadDevices, 30000);
    </script>
</body>
</html>
EOF

# Create working CGI API
cat > /www/cgi-bin/netmon-api.sh << 'EOF'
#!/bin/sh
echo "Content-Type: application/json"
echo "Access-Control-Allow-Origin: *"
echo ""

echo -n '{"success":true,"devices":['
first=1
if [ -f /proc/net/arp ]; then
    while IFS=' ' read -r ip hw_type flags mac mask device; do
        if [ "$ip" != "IP" ] && [ "$mac" != "00:00:00:00:00:00" ] && [ -n "$mac" ]; then
            if [ $first -eq 0 ]; then echo -n ','; fi
            first=0
            hostname="Device-${ip##*.}"
            echo -n "{\\"ip\\":\\"$ip\\",\\"mac\\":\\"$mac\\",\\"hostname\\":\\"$hostname\\",\\"last_seen\\":$(date +%s),\\"is_active\\":true}"
        fi
    done < /proc/net/arp
fi
echo ']}'
EOF

# Set permissions
chmod 644 /www/netmon/index.html
chmod 755 /www/cgi-bin/netmon-api.sh

# Configure uhttpd
if ! grep -q "config uhttpd 'netmon'" /etc/config/uhttpd; then
    cat >> /etc/config/uhttpd << 'EOF'

config uhttpd 'netmon'
    option listen_http '0.0.0.0:8080'
    option home '/www/netmon'
    option cgi_prefix '/cgi-bin'
    option script_timeout '60'
EOF
fi

# Restart uhttpd
/etc/init.d/uhttpd restart

echo "✅ Network Monitor fixed!"
echo "Access: http://$(uci get network.lan.ipaddr):8080/"
"""
        
        with open("auto_fix_netmon.sh", "w") as f:
            f.write(fix_script)
        
        print("✅ Fix script generated: auto_fix_netmon.sh")
        
    def run_tests(self):
        """Run all tests"""
        print("🎯 Starting Network Monitor Web Interface Tests...")
        print("=" * 50)
        
        if not self.setup_driver():
            return False
        
        try:
            # Test main page
            main_page_working = self.test_main_page()
            
            # Test alternative URLs if main page fails
            working_url = None
            if not main_page_working:
                working_url = self.test_alternative_urls()
            else:
                working_url = self.base_url
            
            # Test API endpoints
            working_apis = self.test_api_endpoints()
            
            # Test JavaScript if we have a working URL
            if working_url:
                self.test_javascript_functionality(working_url)
            
            # Generate fix script
            self.generate_fix_script()
            
            # Print summary
            print("\n" + "=" * 50)
            print("📊 TEST SUMMARY")
            print("=" * 50)
            
            for result in self.test_results:
                status_icon = "✅" if result["status"] == "passed" else "❌" if result["status"] == "failed" else "⚠️"
                print(f"{status_icon} {result['test']}: {result['status']}")
                if "error" in result:
                    print(f"   Error: {result['error']}")
            
            if working_url:
                print(f"\n🌐 Working URL: {working_url}")
            
            if working_apis:
                print(f"🔌 Working APIs: {len(working_apis)}")
                for api in working_apis:
                    print(f"   • {api}")
            
            print(f"\n🔧 Auto-fix script generated: auto_fix_netmon.sh")
            print("Run this on your OpenWrt router to fix issues.")
            
        finally:
            if self.driver:
                self.driver.quit()
                print("\n🏁 Browser closed")

def main():
    """Main function"""
    print("🚀 Network Monitor Selenium Tester")
    print("=" * 50)
    
    # Get router IP from user or use default
    router_ip = input("Enter router IP (default: 192.168.1.1): ").strip()
    if not router_ip:
        router_ip = "192.168.1.1"
    
    # Get port from user or use default
    port = input("Enter port (default: 8080): ").strip()
    if not port:
        port = "8080"
    
    tester = NetworkMonitorTester(router_ip, port)
    tester.run_tests()

if __name__ == "__main__":
    main()
