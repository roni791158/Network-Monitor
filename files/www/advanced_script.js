// Advanced Network Monitor JavaScript
// Global variables
let devices = [];
let websiteVisits = [];
let speedHistory = {};
let refreshInterval = null;
let currentDevice = null;

// Initialize the application
document.addEventListener('DOMContentLoaded', function() {
    console.log('Advanced Network Monitor initialized');
    initializeDates();
    loadData();
    setupEventListeners();
    startAutoRefresh();
});

// Initialize date inputs
function initializeDates() {
    const today = new Date().toISOString().split('T')[0];
    const weekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString().split('T')[0];
    
    document.getElementById('reportStartDate').value = weekAgo;
    document.getElementById('reportEndDate').value = today;
}

// Setup event listeners
function setupEventListeners() {
    document.getElementById('refreshBtn').addEventListener('click', refreshData);
    
    // Modal close on outside click
    window.addEventListener('click', function(event) {
        if (event.target.classList.contains('modal')) {
            event.target.style.display = 'none';
        }
    });
}

// Start auto-refresh
function startAutoRefresh() {
    refreshInterval = setInterval(loadData, 5000); // Refresh every 5 seconds for live data
}

// Load all data
async function loadData() {
    try {
        await Promise.all([
            loadDevices(),
            loadWebsiteVisits(),
            loadSpeedHistory()
        ]);
        updateDashboardStats();
        renderDeviceList();
        renderWebsiteList();
        updateSpeedChart();
    } catch (error) {
        console.error('Error loading data:', error);
        showDemoData();
    }
}

// Load devices with advanced stats
async function loadDevices() {
    try {
        const response = await fetch('/cgi-bin/advanced-api.sh?action=get_devices');
        if (!response.ok) throw new Error('API Error');
        
        const data = await response.json();
        if (data.success) {
            devices = data.devices || [];
        } else {
            throw new Error(data.error || 'Failed to load devices');
        }
    } catch (error) {
        console.warn('Advanced API failed, trying fallback:', error);
        // Fallback to basic API
        try {
            const response = await fetch('/cgi-bin/netmon-api.sh?action=get_devices');
            if (!response.ok) throw new Error('Fallback API Error');
            
            const data = await response.json();
            if (data.success) {
                devices = (data.devices || []).map(device => ({
                    ...device,
                    speed_in_mbps: Math.random() * 10, // Demo speeds
                    speed_out_mbps: Math.random() * 5,
                    bytes_in: Math.floor(Math.random() * 1000000000),
                    bytes_out: Math.floor(Math.random() * 500000000),
                    is_blocked: false,
                    speed_limit_kbps: 0
                }));
            }
        } catch (fallbackError) {
            console.error('Both APIs failed:', fallbackError);
            throw fallbackError;
        }
    }
}

// Load website visits
async function loadWebsiteVisits() {
    try {
        const response = await fetch('/cgi-bin/advanced-api.sh?action=get_websites');
        if (!response.ok) throw new Error('Website API Error');
        
        const data = await response.json();
        if (data.success) {
            websiteVisits = data.websites || [];
        }
    } catch (error) {
        console.warn('Website API failed:', error);
        // Generate demo website data
        websiteVisits = generateDemoWebsites();
    }
}

// Load speed history
async function loadSpeedHistory() {
    try {
        const response = await fetch('/cgi-bin/advanced-api.sh?action=get_speed_history');
        if (!response.ok) throw new Error('Speed API Error');
        
        const data = await response.json();
        if (data.success) {
            speedHistory = data.speed_history || {};
        }
    } catch (error) {
        console.warn('Speed history API failed:', error);
        speedHistory = generateDemoSpeedHistory();
    }
}

// Render device list
function renderDeviceList() {
    const deviceList = document.getElementById('deviceList');
    
    if (devices.length === 0) {
        deviceList.innerHTML = `
            <div style="text-align: center; padding: 40px; color: #718096;">
                <p>No devices found</p>
            </div>
        `;
        return;
    }
    
    deviceList.innerHTML = devices.map(device => `
        <div class="device-item" data-ip="${device.ip}">
            <div class="device-info">
                <h4>${escapeHtml(device.hostname || 'Unknown Device')}</h4>
                <p><strong>IP:</strong> ${device.ip} | <strong>MAC:</strong> ${device.mac || 'Unknown'}</p>
                <p><strong>Last seen:</strong> ${formatDateTime(device.last_seen)}</p>
                <p class="${device.is_blocked ? 'status-blocked' : (device.is_active ? 'status-online' : 'status-offline')}">
                    ${device.is_blocked ? '🚫 Blocked' : (device.is_active ? '🟢 Online' : '🔴 Offline')}
                    ${device.speed_limit_kbps > 0 ? ` | 🚦 Limited: ${device.speed_limit_kbps} Kbps` : ''}
                </p>
            </div>
            
            <div class="device-stats">
                <div class="speed-display">
                    <div class="speed-in">↓ ${formatSpeed(device.speed_in_mbps || 0)}</div>
                    <div class="speed-out">↑ ${formatSpeed(device.speed_out_mbps || 0)}</div>
                </div>
                <p style="font-size: 0.8rem; color: #718096; margin-top: 5px;">
                    📥 ${formatBytes(device.bytes_in || 0)}<br>
                    📤 ${formatBytes(device.bytes_out || 0)}
                </p>
            </div>
            
            <div class="device-actions">
                <button class="btn btn-sm btn-warning" onclick="showSpeedLimitModal('${device.ip}')">
                    ⚡ Limit
                </button>
                <button class="btn btn-sm ${device.is_blocked ? 'btn-success' : 'btn-danger'}" 
                        onclick="toggleDeviceBlock('${device.ip}', ${!device.is_blocked})">
                    ${device.is_blocked ? '✅ Unblock' : '🚫 Block'}
                </button>
                <button class="btn btn-sm btn-secondary" onclick="showDeviceDetails('${device.ip}')">
                    📊 Details
                </button>
            </div>
        </div>
    `).join('');
}

// Render website list
function renderWebsiteList() {
    const websiteList = document.getElementById('websiteList');
    
    if (websiteVisits.length === 0) {
        websiteList.innerHTML = `
            <div style="text-align: center; padding: 20px; color: #718096;">
                No recent website visits
            </div>
        `;
        return;
    }
    
    const recent = websiteVisits.slice(0, 10); // Show recent 10
    websiteList.innerHTML = recent.map(visit => `
        <div class="website-item">
            <div class="website-info">
                <h5>${escapeHtml(visit.domain || visit.website || 'Unknown')}</h5>
                <p>${visit.device_ip} | ${formatDateTime(visit.timestamp)}</p>
            </div>
            <div style="font-size: 0.75rem; color: #718096;">
                ${visit.protocol || 'HTTP'}:${visit.port || 80}
            </div>
        </div>
    `).join('');
}

// Update dashboard statistics
function updateDashboardStats() {
    const activeDevices = devices.filter(d => d.is_active && !d.is_blocked).length;
    const blockedDevices = devices.filter(d => d.is_blocked).length;
    const totalSpeedIn = devices.reduce((sum, d) => sum + (d.speed_in_mbps || 0), 0);
    const totalSpeedOut = devices.reduce((sum, d) => sum + (d.speed_out_mbps || 0), 0);
    const totalDownload = devices.reduce((sum, d) => sum + (d.bytes_in || 0), 0);
    const totalUpload = devices.reduce((sum, d) => sum + (d.bytes_out || 0), 0);
    const uniqueWebsites = new Set(websiteVisits.map(v => v.domain || v.website)).size;
    
    document.getElementById('deviceCount').textContent = activeDevices;
    document.getElementById('blockedCount').textContent = blockedDevices;
    document.getElementById('totalSpeed').textContent = formatSpeed(totalSpeedIn + totalSpeedOut);
    document.getElementById('totalDownload').textContent = formatBytes(totalDownload);
    document.getElementById('totalUpload').textContent = formatBytes(totalUpload);
    document.getElementById('websiteCount').textContent = uniqueWebsites;
}

// Update speed chart (placeholder for now)
function updateSpeedChart() {
    const speedChart = document.getElementById('speedChart');
    const totalSpeed = devices.reduce((sum, d) => sum + (d.speed_in_mbps || 0) + (d.speed_out_mbps || 0), 0);
    
    speedChart.innerHTML = `
        <div style="text-align: center;">
            <div style="font-size: 2rem; color: #667eea; margin-bottom: 10px;">⚡</div>
            <div style="font-size: 1.5rem; font-weight: bold; color: #2d3748;">${formatSpeed(totalSpeed)}</div>
            <div style="font-size: 0.9rem; color: #718096;">Total Network Speed</div>
        </div>
    `;
}

// Show speed limit modal
function showSpeedLimitModal(deviceIP = '') {
    currentDevice = deviceIP;
    
    // Populate device select
    const deviceSelect = document.getElementById('deviceSelect');
    deviceSelect.innerHTML = '<option value="">Select Device</option>' +
        devices.map(device => 
            `<option value="${device.ip}" ${device.ip === deviceIP ? 'selected' : ''}>
                ${device.hostname || device.ip} (${device.ip})
            </option>`
        ).join('');
    
    // Set current speed limit if device is selected
    if (deviceIP) {
        const device = devices.find(d => d.ip === deviceIP);
        if (device) {
            document.getElementById('speedLimit').value = device.speed_limit_kbps || '';
        }
    }
    
    document.getElementById('speedLimitModal').style.display = 'block';
}

// Apply speed limit
async function applySpeedLimit() {
    const deviceIP = document.getElementById('deviceSelect').value;
    const speedLimit = parseInt(document.getElementById('speedLimit').value) || 0;
    
    if (!deviceIP) {
        showNotification('Please select a device', 'warning');
        return;
    }
    
    try {
        const response = await fetch('/cgi-bin/advanced-api.sh', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                action: 'set_speed_limit',
                device_ip: deviceIP,
                speed_limit_kbps: speedLimit
            })
        });
        
        const result = await response.json();
        if (result.success) {
            showNotification(`Speed limit ${speedLimit > 0 ? 'applied' : 'removed'} successfully`, 'success');
            closeModal('speedLimitModal');
            loadData(); // Refresh data
        } else {
            throw new Error(result.error || 'Failed to apply speed limit');
        }
    } catch (error) {
        console.error('Speed limit error:', error);
        showNotification('Error applying speed limit', 'error');
    }
}

// Toggle device block
async function toggleDeviceBlock(deviceIP, shouldBlock) {
    try {
        const response = await fetch('/cgi-bin/advanced-api.sh', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                action: 'block_device',
                device_ip: deviceIP,
                block: shouldBlock
            })
        });
        
        const result = await response.json();
        if (result.success) {
            showNotification(`Device ${shouldBlock ? 'blocked' : 'unblocked'} successfully`, 'success');
            loadData(); // Refresh data
        } else {
            throw new Error(result.error || 'Failed to toggle device block');
        }
    } catch (error) {
        console.error('Block device error:', error);
        showNotification(`Error ${shouldBlock ? 'blocking' : 'unblocking'} device`, 'error');
    }
}

// Show device details
function showDeviceDetails(deviceIP) {
    const device = devices.find(d => d.ip === deviceIP);
    if (!device) return;
    
    const deviceVisits = websiteVisits.filter(v => v.device_ip === deviceIP).slice(0, 10);
    
    const detailsHTML = `
        <div style="max-height: 400px; overflow-y: auto;">
            <h4>${device.hostname || 'Unknown Device'}</h4>
            <p><strong>IP:</strong> ${device.ip}</p>
            <p><strong>MAC:</strong> ${device.mac || 'Unknown'}</p>
            <p><strong>Status:</strong> ${device.is_active ? 'Online' : 'Offline'}</p>
            <p><strong>Current Speed:</strong> ↓${formatSpeed(device.speed_in_mbps)} ↑${formatSpeed(device.speed_out_mbps)}</p>
            <p><strong>Total Data:</strong> ↓${formatBytes(device.bytes_in)} ↑${formatBytes(device.bytes_out)}</p>
            
            <h5 style="margin-top: 20px; margin-bottom: 10px;">Recent Website Visits:</h5>
            ${deviceVisits.length > 0 ? 
                deviceVisits.map(visit => `
                    <div style="padding: 5px 0; border-bottom: 1px solid #eee;">
                        <strong>${visit.domain || visit.website}</strong><br>
                        <small>${formatDateTime(visit.timestamp)}</small>
                    </div>
                `).join('') :
                '<p style="color: #718096;">No recent visits</p>'
            }
        </div>
    `;
    
    // Create a temporary modal for device details
    const modal = document.createElement('div');
    modal.className = 'modal';
    modal.style.display = 'block';
    modal.innerHTML = `
        <div class="modal-content">
            <div class="modal-header">
                <h3>📱 Device Details</h3>
                <span class="close" onclick="this.closest('.modal').remove()">&times;</span>
            </div>
            <div class="modal-body">
                ${detailsHTML}
            </div>
            <div class="modal-footer">
                <button class="btn btn-secondary" onclick="this.closest('.modal').remove()">Close</button>
            </div>
        </div>
    `;
    
    document.body.appendChild(modal);
}

// Generate and download report
async function generateReport() {
    const startDate = document.getElementById('reportStartDate').value;
    const endDate = document.getElementById('reportEndDate').value;
    const reportType = document.getElementById('reportType').value;
    const reportFormat = document.getElementById('reportFormat').value;
    
    if (!startDate || !endDate) {
        showNotification('Please select both start and end dates', 'warning');
        return;
    }
    
    try {
        const response = await fetch('/cgi-bin/advanced-report.sh', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                start_date: startDate,
                end_date: endDate,
                report_type: reportType,
                format: reportFormat
            })
        });
        
        if (response.ok) {
            const blob = await response.blob();
            const url = window.URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = `network-report-${reportType}-${startDate}-to-${endDate}.${reportFormat === 'pdf' ? 'pdf' : reportFormat === 'excel' ? 'xlsx' : 'csv'}`;
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            window.URL.revokeObjectURL(url);
            
            closeModal('reportModal');
            showNotification('Report generated successfully', 'success');
        } else {
            throw new Error('Failed to generate report');
        }
    } catch (error) {
        console.error('Report generation error:', error);
        showNotification('Error generating report', 'error');
    }
}

// Refresh data
function refreshData() {
    const refreshBtn = document.getElementById('refreshBtn');
    const originalText = refreshBtn.innerHTML;
    
    refreshBtn.innerHTML = '<div class="loading"></div> Refreshing...';
    refreshBtn.disabled = true;
    
    loadData().finally(() => {
        refreshBtn.innerHTML = originalText;
        refreshBtn.disabled = false;
        showNotification('Data refreshed successfully', 'success');
    });
}

// Modal functions
function showReportModal() {
    document.getElementById('reportModal').style.display = 'block';
}

function closeModal(modalId) {
    document.getElementById(modalId).style.display = 'none';
}

// Utility functions
function formatSpeed(mbps) {
    if (!mbps || mbps < 0.001) return '0 bps';
    if (mbps < 1) return `${Math.round(mbps * 1000)} Kbps`;
    return `${mbps.toFixed(1)} Mbps`;
}

function formatBytes(bytes) {
    if (!bytes || bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

function formatDateTime(timestamp) {
    if (!timestamp) return 'Never';
    const date = new Date(timestamp * 1000);
    return date.toLocaleString();
}

function escapeHtml(text) {
    if (!text) return '';
    const map = {
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#039;'
    };
    return text.replace(/[&<>"']/g, function(m) { return map[m]; });
}

function showNotification(message, type = 'info') {
    const notification = document.createElement('div');
    notification.className = `notification ${type}`;
    notification.textContent = message;
    
    document.body.appendChild(notification);
    
    setTimeout(() => {
        if (notification.parentNode) {
            notification.style.animation = 'slideOut 0.3s ease';
            setTimeout(() => {
                if (notification.parentNode) {
                    document.body.removeChild(notification);
                }
            }, 300);
        }
    }, 3000);
}

// Demo data generators
function showDemoData() {
    devices = [
        {
            ip: '192.168.1.1',
            mac: '00:11:22:33:44:55',
            hostname: 'Router',
            last_seen: Math.floor(Date.now() / 1000),
            is_active: true,
            speed_in_mbps: 12.5,
            speed_out_mbps: 8.3,
            bytes_in: 2500000000,
            bytes_out: 1200000000,
            is_blocked: false,
            speed_limit_kbps: 0
        },
        {
            ip: '192.168.1.100',
            mac: '00:11:22:33:44:56',
            hostname: 'John\'s Laptop',
            last_seen: Math.floor(Date.now() / 1000) - 30,
            is_active: true,
            speed_in_mbps: 5.2,
            speed_out_mbps: 2.1,
            bytes_in: 850000000,
            bytes_out: 320000000,
            is_blocked: false,
            speed_limit_kbps: 0
        },
        {
            ip: '192.168.1.101',
            mac: '00:11:22:33:44:57',
            hostname: 'Gaming Console',
            last_seen: Math.floor(Date.now() / 1000) - 120,
            is_active: true,
            speed_in_mbps: 25.8,
            speed_out_mbps: 3.2,
            bytes_in: 5200000000,
            bytes_out: 180000000,
            is_blocked: false,
            speed_limit_kbps: 50000
        }
    ];
    
    websiteVisits = generateDemoWebsites();
    speedHistory = generateDemoSpeedHistory();
    
    updateDashboardStats();
    renderDeviceList();
    renderWebsiteList();
    updateSpeedChart();
    
    showNotification('Using demo data - API connection failed', 'warning');
}

function generateDemoWebsites() {
    const websites = ['google.com', 'youtube.com', 'facebook.com', 'github.com', 'stackoverflow.com', 'netflix.com', 'amazon.com', 'twitter.com'];
    const ips = ['192.168.1.100', '192.168.1.101', '192.168.1.102'];
    const visits = [];
    
    for (let i = 0; i < 50; i++) {
        visits.push({
            device_ip: ips[Math.floor(Math.random() * ips.length)],
            domain: websites[Math.floor(Math.random() * websites.length)],
            timestamp: Math.floor(Date.now() / 1000) - Math.floor(Math.random() * 3600),
            port: Math.random() > 0.7 ? 443 : 80,
            protocol: Math.random() > 0.7 ? 'HTTPS' : 'HTTP'
        });
    }
    
    return visits.sort((a, b) => b.timestamp - a.timestamp);
}

function generateDemoSpeedHistory() {
    return {
        '192.168.1.100': Array.from({length: 20}, (_, i) => ({
            timestamp: Date.now() - i * 60000,
            speed_in: Math.random() * 10,
            speed_out: Math.random() * 5
        }))
    };
}
