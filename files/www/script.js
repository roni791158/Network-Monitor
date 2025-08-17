// Global variables
let devices = [];
let trafficData = [];
let websiteHistory = [];
let trafficChart = null;

// Initialize the application
document.addEventListener('DOMContentLoaded', function() {
    initializeDates();
    loadData();
    setupEventListeners();
});

// Initialize date inputs with current date
function initializeDates() {
    const today = new Date().toISOString().split('T')[0];
    const weekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString().split('T')[0];
    
    document.getElementById('startDate').value = weekAgo;
    document.getElementById('endDate').value = today;
    document.getElementById('reportStartDate').value = weekAgo;
    document.getElementById('reportEndDate').value = today;
}

// Setup event listeners
function setupEventListeners() {
    // Auto-refresh every 30 seconds
    setInterval(loadData, 30000);
}

// Load all data
async function loadData() {
    try {
        await Promise.all([
            loadDevices(),
            loadTrafficData(),
            loadWebsiteHistory()
        ]);
        updateDashboardStats();
    } catch (error) {
        console.error('Error loading data:', error);
        showNotification('Error loading data', 'error');
    }
}

// Load connected devices
async function loadDevices() {
    try {
        const response = await fetch('/cgi-bin/netmon-api.lua?action=get_devices');
        const data = await response.json();
        
        if (data.success) {
            devices = data.devices || [];
            renderDevicesTable();
        } else {
            throw new Error(data.error || 'Failed to load devices');
        }
    } catch (error) {
        console.error('Error loading devices:', error);
        // Fallback to demo data for development
        devices = generateDemoDevices();
        renderDevicesTable();
    }
}

// Load traffic data
async function loadTrafficData() {
    try {
        const startDate = document.getElementById('startDate').value;
        const endDate = document.getElementById('endDate').value;
        
        const response = await fetch(`/cgi-bin/netmon-api.lua?action=get_traffic&start_date=${startDate}&end_date=${endDate}`);
        const data = await response.json();
        
        if (data.success) {
            trafficData = data.traffic || [];
            renderTrafficChart();
        } else {
            throw new Error(data.error || 'Failed to load traffic data');
        }
    } catch (error) {
        console.error('Error loading traffic data:', error);
        // Fallback to demo data
        trafficData = generateDemoTraffic();
        renderTrafficChart();
    }
}

// Load website history
async function loadWebsiteHistory() {
    try {
        const response = await fetch('/cgi-bin/netmon-api.lua?action=get_websites');
        const data = await response.json();
        
        if (data.success) {
            websiteHistory = data.websites || [];
            renderWebsiteHistory();
        } else {
            throw new Error(data.error || 'Failed to load website history');
        }
    } catch (error) {
        console.error('Error loading website history:', error);
        // Fallback to demo data
        websiteHistory = generateDemoWebsites();
        renderWebsiteHistory();
    }
}

// Render devices table
function renderDevicesTable() {
    const tbody = document.getElementById('devicesTableBody');
    tbody.innerHTML = '';
    
    devices.forEach(device => {
        const row = document.createElement('tr');
        row.innerHTML = `
            <td>${device.hostname || 'Unknown Device'}</td>
            <td>${device.ip}</td>
            <td>${device.mac}</td>
            <td>${formatDateTime(device.last_seen)}</td>
            <td><span class="status-badge ${device.is_active ? 'status-online' : 'status-offline'}">${device.is_active ? 'Online' : 'Offline'}</span></td>
            <td>${formatBytes(device.total_bytes || 0)}</td>
        `;
        tbody.appendChild(row);
    });
}

// Render traffic chart
function renderTrafficChart() {
    const ctx = document.getElementById('trafficChart').getContext('2d');
    
    // Destroy existing chart
    if (trafficChart) {
        trafficChart.destroy();
    }
    
    // Process traffic data by date
    const dailyTraffic = {};
    trafficData.forEach(record => {
        const date = new Date(record.timestamp * 1000).toISOString().split('T')[0];
        if (!dailyTraffic[date]) {
            dailyTraffic[date] = { download: 0, upload: 0 };
        }
        dailyTraffic[date].download += record.bytes_received || 0;
        dailyTraffic[date].upload += record.bytes_sent || 0;
    });
    
    const labels = Object.keys(dailyTraffic).sort();
    const downloadData = labels.map(date => dailyTraffic[date].download / (1024 * 1024)); // Convert to MB
    const uploadData = labels.map(date => dailyTraffic[date].upload / (1024 * 1024));
    
    trafficChart = new Chart(ctx, {
        type: 'line',
        data: {
            labels: labels.map(date => formatDate(date)),
            datasets: [{
                label: 'Download (MB)',
                data: downloadData,
                borderColor: '#667eea',
                backgroundColor: 'rgba(102, 126, 234, 0.1)',
                fill: true,
                tension: 0.4
            }, {
                label: 'Upload (MB)',
                data: uploadData,
                borderColor: '#764ba2',
                backgroundColor: 'rgba(118, 75, 162, 0.1)',
                fill: true,
                tension: 0.4
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    position: 'top',
                }
            },
            scales: {
                y: {
                    beginAtZero: true,
                    title: {
                        display: true,
                        text: 'Data (MB)'
                    }
                }
            }
        }
    });
}

// Render website history
function renderWebsiteHistory() {
    const tbody = document.getElementById('websitesTableBody');
    tbody.innerHTML = '';
    
    websiteHistory.slice(0, 100).forEach(record => { // Show latest 100 records
        const row = document.createElement('tr');
        row.innerHTML = `
            <td>${record.url || 'Unknown'}</td>
            <td>${record.ip}</td>
            <td>${formatDateTime(record.timestamp)}</td>
            <td>${formatBytes((record.bytes_sent || 0) + (record.bytes_received || 0))}</td>
        `;
        tbody.appendChild(row);
    });
}

// Update dashboard statistics
function updateDashboardStats() {
    // Device count
    document.getElementById('deviceCount').textContent = devices.filter(d => d.is_active).length;
    
    // Total data usage
    const totalDownload = trafficData.reduce((sum, record) => sum + (record.bytes_received || 0), 0);
    const totalUpload = trafficData.reduce((sum, record) => sum + (record.bytes_sent || 0), 0);
    
    document.getElementById('totalDownload').textContent = formatBytes(totalDownload);
    document.getElementById('totalUpload').textContent = formatBytes(totalUpload);
    
    // Unique websites
    const uniqueWebsites = new Set(websiteHistory.map(record => record.url)).size;
    document.getElementById('websiteCount').textContent = uniqueWebsites;
}

// Tab functionality
function showTab(tabName) {
    // Hide all tabs
    document.querySelectorAll('.tab-pane').forEach(pane => {
        pane.classList.remove('active');
    });
    
    // Remove active class from all buttons
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.classList.remove('active');
    });
    
    // Show selected tab
    document.getElementById(tabName + '-tab').classList.add('active');
    
    // Add active class to clicked button
    event.target.classList.add('active');
}

// Filter traffic data
function filterTraffic() {
    loadTrafficData();
}

// Refresh all data
function refreshData() {
    const button = event.target;
    const originalText = button.innerHTML;
    
    button.innerHTML = '<div class="loading"></div> Refreshing...';
    button.disabled = true;
    
    loadData().finally(() => {
        button.innerHTML = originalText;
        button.disabled = false;
        showNotification('Data refreshed successfully', 'success');
    });
}

// Modal functions
function showReportModal() {
    document.getElementById('reportModal').style.display = 'block';
}

function closeReportModal() {
    document.getElementById('reportModal').style.display = 'none';
}

// Generate PDF report
async function generateReport() {
    const startDate = document.getElementById('reportStartDate').value;
    const endDate = document.getElementById('reportEndDate').value;
    const reportType = document.getElementById('reportType').value;
    
    if (!startDate || !endDate) {
        showNotification('Please select both start and end dates', 'error');
        return;
    }
    
    try {
        const response = await fetch('/cgi-bin/netmon-report.lua', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                start_date: startDate,
                end_date: endDate,
                report_type: reportType
            })
        });
        
        if (response.ok) {
            const blob = await response.blob();
            const url = window.URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = `network-report-${startDate}-to-${endDate}.pdf`;
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            window.URL.revokeObjectURL(url);
            
            closeReportModal();
            showNotification('Report generated successfully', 'success');
        } else {
            throw new Error('Failed to generate report');
        }
    } catch (error) {
        console.error('Error generating report:', error);
        showNotification('Error generating report', 'error');
    }
}

// Utility functions
function formatBytes(bytes) {
    if (bytes === 0) return '0 B';
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

function formatDate(dateString) {
    const date = new Date(dateString);
    return date.toLocaleDateString();
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
        background: ${type === 'success' ? '#48bb78' : type === 'error' ? '#f56565' : '#4299e1'};
        color: white;
        border-radius: 8px;
        box-shadow: 0 4px 15px rgba(0, 0, 0, 0.2);
        z-index: 1001;
        font-weight: 600;
        animation: slideIn 0.3s ease;
    `;
    
    document.body.appendChild(notification);
    
    // Remove after 3 seconds
    setTimeout(() => {
        notification.style.animation = 'slideOut 0.3s ease';
        setTimeout(() => {
            document.body.removeChild(notification);
        }, 300);
    }, 3000);
}

// Demo data generators (for development/fallback)
function generateDemoDevices() {
    return [
        {
            ip: '192.168.1.101',
            mac: '00:11:22:33:44:55',
            hostname: 'John-Laptop',
            last_seen: Math.floor(Date.now() / 1000),
            is_active: true,
            total_bytes: 1024 * 1024 * 150
        },
        {
            ip: '192.168.1.102',
            mac: '00:11:22:33:44:56',
            hostname: 'Samsung-Phone',
            last_seen: Math.floor(Date.now() / 1000) - 300,
            is_active: true,
            total_bytes: 1024 * 1024 * 89
        },
        {
            ip: '192.168.1.103',
            mac: '00:11:22:33:44:57',
            hostname: 'Smart-TV',
            last_seen: Math.floor(Date.now() / 1000) - 3600,
            is_active: false,
            total_bytes: 1024 * 1024 * 45
        }
    ];
}

function generateDemoTraffic() {
    const traffic = [];
    const now = Date.now();
    
    for (let i = 7; i >= 0; i--) {
        const timestamp = Math.floor((now - i * 24 * 60 * 60 * 1000) / 1000);
        traffic.push({
            ip: '192.168.1.101',
            timestamp: timestamp,
            bytes_sent: Math.floor(Math.random() * 1024 * 1024 * 50),
            bytes_received: Math.floor(Math.random() * 1024 * 1024 * 200)
        });
    }
    
    return traffic;
}

function generateDemoWebsites() {
    const websites = ['google.com', 'facebook.com', 'youtube.com', 'github.com', 'stackoverflow.com'];
    const history = [];
    
    for (let i = 0; i < 50; i++) {
        history.push({
            ip: '192.168.1.10' + (1 + Math.floor(Math.random() * 3)),
            url: websites[Math.floor(Math.random() * websites.length)],
            timestamp: Math.floor(Date.now() / 1000) - Math.floor(Math.random() * 7 * 24 * 60 * 60),
            bytes_sent: Math.floor(Math.random() * 1024 * 100),
            bytes_received: Math.floor(Math.random() * 1024 * 500)
        });
    }
    
    return history.sort((a, b) => b.timestamp - a.timestamp);
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
`;
document.head.appendChild(style);
