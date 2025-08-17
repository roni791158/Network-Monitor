// Network Monitor JavaScript - External file to avoid CSP issues
// Global variables
let devices = [];
let trafficData = [];
let websiteHistory = [];
let trafficChart = null;

// Initialize the application
document.addEventListener('DOMContentLoaded', function() {
    console.log('Network Monitor initialized');
    loadData();
    setupEventListeners();
});

// Setup event listeners
function setupEventListeners() {
    // Auto-refresh every 30 seconds
    setInterval(loadData, 30000);
    
    // Add refresh button event listener
    const refreshBtn = document.getElementById('refreshBtn');
    if (refreshBtn) {
        refreshBtn.addEventListener('click', function() {
            refreshData();
        });
    }
}

// Load all data
async function loadData() {
    try {
        console.log('Loading device data...');
        await loadDevices();
        updateDashboardStats();
    } catch (error) {
        console.error('Error loading data:', error);
        showDemoData();
    }
}

// Load connected devices with fallback options
async function loadDevices() {
    const apiUrls = [
        '/cgi-bin/netmon-api.sh?action=get_devices',
        '/cgi-bin/netmon-api.lua?action=get_devices'
    ];
    
    for (const url of apiUrls) {
        try {
            console.log(`Trying API: ${url}`);
            const response = await fetch(url);
            
            if (!response.ok) {
                console.warn(`API ${url} returned status: ${response.status}`);
                continue;
            }
            
            const text = await response.text();
            console.log(`API response: ${text.substring(0, 100)}...`);
            
            const data = JSON.parse(text);
            
            if (data.success) {
                devices = data.devices || [];
                console.log(`Loaded ${devices.length} devices`);
                renderDevicesTable();
                return;
            } else {
                console.warn(`API ${url} returned error:`, data.error);
            }
        } catch (error) {
            console.warn(`Failed to load from ${url}:`, error);
        }
    }
    
    // If all APIs fail, show demo data
    throw new Error('All API endpoints failed');
}

// Render devices table
function renderDevicesTable() {
    const deviceList = document.getElementById('deviceList');
    if (!deviceList) return;
    
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
                <h4>${escapeHtml(device.hostname || 'Unknown Device')}</h4>
                <p>IP: ${escapeHtml(device.ip)} | MAC: ${escapeHtml(device.mac || 'Unknown')}</p>
                <p>Last seen: ${formatDateTime(device.last_seen)}</p>
            </div>
            <div class="device-status ${device.is_active ? 'status-online' : 'status-offline'}">
                ${device.is_active ? 'Online' : 'Offline'}
            </div>
        `;
        deviceList.appendChild(li);
    });
}

// Update dashboard statistics
function updateDashboardStats() {
    // Device count
    const deviceCountEl = document.getElementById('deviceCount');
    if (deviceCountEl) {
        const activeDevices = devices.filter(d => d.is_active).length;
        deviceCountEl.textContent = activeDevices.toString();
    }
    
    // For now, set static values for other stats
    const totalDownloadEl = document.getElementById('totalDownload');
    if (totalDownloadEl) {
        totalDownloadEl.textContent = '0 MB';
    }
    
    const totalUploadEl = document.getElementById('totalUpload');
    if (totalUploadEl) {
        totalUploadEl.textContent = '0 MB';
    }
    
    const websiteCountEl = document.getElementById('websiteCount');
    if (websiteCountEl) {
        websiteCountEl.textContent = '0';
    }
}

// Show demo data if API fails
function showDemoData() {
    console.log('Showing demo data due to API failure');
    
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
            hostname: 'Demo Device 1',
            last_seen: Math.floor(Date.now() / 1000) - 120,
            is_active: true
        },
        {
            ip: '192.168.1.101',
            mac: '00:11:22:33:44:57',
            hostname: 'Demo Device 2',
            last_seen: Math.floor(Date.now() / 1000) - 3600,
            is_active: false
        }
    ];
    
    devices = demoDevices;
    renderDevicesTable();
    updateDashboardStats();
    
    showNotification('Using demo data - API connection failed', 'warning');
}

// Refresh all data with loading indicator
function refreshData() {
    const refreshBtn = document.getElementById('refreshBtn');
    if (refreshBtn) {
        const originalText = refreshBtn.innerHTML;
        refreshBtn.innerHTML = '<div class="loading"></div> Refreshing...';
        refreshBtn.disabled = true;
        
        loadData().finally(() => {
            refreshBtn.innerHTML = originalText;
            refreshBtn.disabled = false;
            showNotification('Data refreshed successfully', 'success');
        });
    } else {
        loadData();
    }
}

// Utility functions
function formatDateTime(timestamp) {
    if (!timestamp) return 'Never';
    const date = new Date(timestamp * 1000);
    return date.toLocaleString();
}

function formatBytes(bytes) {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

function escapeHtml(text) {
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
    // Create notification element
    const notification = document.createElement('div');
    notification.className = `notification notification-${type}`;
    notification.textContent = message;
    
    // Add styles
    notification.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        padding: 15px 20px;
        background: ${type === 'success' ? '#48bb78' : type === 'error' ? '#f56565' : type === 'warning' ? '#ed8936' : '#4299e1'};
        color: white;
        border-radius: 8px;
        box-shadow: 0 4px 15px rgba(0, 0, 0, 0.2);
        z-index: 1001;
        font-weight: 600;
        animation: slideIn 0.3s ease;
        max-width: 300px;
    `;
    
    document.body.appendChild(notification);
    
    // Remove after 3 seconds
    setTimeout(() => {
        notification.style.animation = 'slideOut 0.3s ease';
        setTimeout(() => {
            if (notification.parentNode) {
                document.body.removeChild(notification);
            }
        }, 300);
    }, 3000);
}

// Add CSS animations
const style = document.createElement('style');
style.textContent = `
    @keyframes slideIn {
        from { transform: translateX(100%); opacity: 0; }
        to { transform: translateX(0); opacity: 1; }
    }
    @keyframes slideOut {
        from { transform: translateX(0); opacity: 1; }
        to { transform: translateX(100%); opacity: 0; }
    }
    
    .loading {
        display: inline-block;
        width: 16px;
        height: 16px;
        border: 2px solid #f3f3f3;
        border-top: 2px solid #667eea;
        border-radius: 50%;
        animation: spin 1s linear infinite;
    }
    
    @keyframes spin {
        0% { transform: rotate(0deg); }
        100% { transform: rotate(360deg); }
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
        font-size: 1rem;
    }
    
    .device-info p {
        color: #718096;
        font-size: 0.875rem;
        margin: 2px 0;
    }
    
    .device-status {
        padding: 6px 12px;
        border-radius: 20px;
        font-size: 0.75rem;
        font-weight: 600;
        text-transform: uppercase;
        white-space: nowrap;
    }
    
    .status-online {
        background: #c6f6d5;
        color: #22543d;
    }
    
    .status-offline {
        background: #fed7d7;
        color: #742a2a;
    }
    
    @media (max-width: 768px) {
        .device-item {
            flex-direction: column;
            align-items: flex-start;
            gap: 10px;
        }
        
        .device-status {
            align-self: flex-end;
        }
    }
`;

if (!document.head.querySelector('style[data-netmon]')) {
    style.setAttribute('data-netmon', 'true');
    document.head.appendChild(style);
}