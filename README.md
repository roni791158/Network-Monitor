# Network Monitor for OpenWrt

A comprehensive network monitoring package for OpenWrt routers with a modern web interface. Monitor connected devices, track data usage, log website visits, and generate detailed reports.

## Features

- **Device Detection**: Automatically discover and track connected devices
- **Real-time Monitoring**: Monitor network traffic in real-time
- **Data Usage Tracking**: Track upload/download statistics per device
- **Website Logging**: Log visited websites with timestamps
- **Modern Web UI**: Beautiful, responsive web interface
- **PDF Reports**: Generate detailed reports for specified date ranges
- **LuCI Integration**: Seamless integration with OpenWrt's web interface

## Screenshots

![Dashboard](docs/dashboard.png)
*Modern dashboard with real-time statistics*

![Device List](docs/devices.png)
*Connected devices with usage statistics*

![Traffic Analysis](docs/traffic.png)
*Traffic analysis with interactive charts*

## Installation

### Quick Install (Recommended)

```bash
# Download and run the installation script
wget -O - https://raw.githubusercontent.com/roni791158/Network-Monitor/main/install.sh | sh
```

### Manual Installation

1. **Download the package:**
   ```bash
   git clone https://github.com/roni791158/Network-Monitor.git
   cd Network-Monitor
   ```

2. **Run the installation script:**
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

### Prerequisites

- OpenWrt 21.02 or newer
- At least 10MB free storage space
- Internet connection for downloading dependencies

## Usage

### Web Interface

After installation, access the Network Monitor web interface:

- **Standalone Interface**: `http://your-router-ip:8080/netmon`
- **LuCI Integration**: System → Administration → Network Monitor

### Default Login

The web interface uses the same authentication as your OpenWrt router.

### Features Overview

#### Dashboard
- Real-time device count
- Total data usage statistics  
- Website visit counters
- Quick access to all features

#### Device Monitoring
- List all connected devices
- Device hostnames and MAC addresses
- Last seen timestamps
- Online/offline status
- Per-device data usage

#### Traffic Analysis
- Interactive traffic charts
- Filter by date range
- Daily upload/download statistics
- Visual data representation

#### Website History
- Complete browsing history
- Visited websites per device
- Timestamps and data usage
- Search and filter capabilities

#### Report Generation
- Generate PDF reports
- Customizable date ranges
- Multiple report types:
  - Summary Report
  - Detailed Report  
  - Device-wise Report

## Configuration

### Service Configuration

Edit the configuration file:
```bash
vi /etc/config/netmon
```

Available options:
- `enabled`: Enable/disable monitoring (default: 1)
- `interface`: Network interface to monitor (default: lan)
- `log_level`: Logging level (default: info)
- `data_retention`: Days to keep data (default: 30)
- `update_interval`: Update frequency in seconds (default: 60)
- `web_port`: Web interface port (default: 8080)

### Service Management

```bash
# Start the service
/etc/init.d/netmon start

# Stop the service
/etc/init.d/netmon stop

# Restart the service
/etc/init.d/netmon restart

# Check service status
/etc/init.d/netmon status

# Enable auto-start
/etc/init.d/netmon enable

# Disable auto-start
/etc/init.d/netmon disable
```

## API Documentation

The Network Monitor provides a REST API for integration with other applications.

### Endpoints

#### Get Connected Devices
```
GET /cgi-bin/netmon-api.lua?action=get_devices
```

#### Get Traffic Data
```
GET /cgi-bin/netmon-api.lua?action=get_traffic&start_date=2024-01-01&end_date=2024-01-31
```

#### Get Website History
```
GET /cgi-bin/netmon-api.lua?action=get_websites
```

#### Get Statistics
```
GET /cgi-bin/netmon-api.lua?action=get_stats
```

### Response Format

All API responses follow this format:
```json
{
  "success": true,
  "data": { ... },
  "error": null
}
```

## File Structure

```
Network-Monitor/
├── Makefile                    # OpenWrt package Makefile
├── src/                        # Source code
│   ├── netmon.c               # Main daemon
│   ├── netmon.h               # Header file
│   ├── db_manager.c           # Database operations
│   ├── network_utils.c        # Network utilities
│   └── Makefile               # Build configuration
├── files/                      # Package files
│   ├── netmon.init            # Init script
│   ├── netmon.config          # UCI configuration
│   ├── www/                   # Web interface
│   │   ├── index.html         # Main page
│   │   ├── style.css          # Styles
│   │   ├── script.js          # JavaScript
│   │   └── cgi-bin/           # CGI scripts
│   └── luci/                  # LuCI integration
├── install.sh                 # Installation script
├── uninstall.sh              # Uninstallation script
└── README.md                 # This file
```

## Development

### Building from Source

1. **Set up build environment:**
   ```bash
   # Install OpenWrt SDK
   wget https://downloads.openwrt.org/releases/22.03.0/targets/x86/64/openwrt-sdk-22.03.0-x86-64_gcc-11.2.0_musl.Linux-x86_64.tar.xz
   tar -xf openwrt-sdk-*.tar.xz
   cd openwrt-sdk-*
   ```

2. **Copy package to SDK:**
   ```bash
   cp -r /path/to/Network-Monitor package/
   ```

3. **Build package:**
   ```bash
   make package/Network-Monitor/compile
   ```

### Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## Troubleshooting

### Common Issues

#### Service Won't Start
```bash
# Check system logs
logread | grep netmon

# Check configuration
cat /etc/config/netmon

# Verify dependencies
opkg list-installed | grep -E "(netfilter|sqlite)"
```

#### Web Interface Not Accessible
```bash
# Check uhttpd status
/etc/init.d/uhttpd status

# Verify port is open
netstat -ln | grep :8080

# Check firewall rules
iptables -L -n
```

#### No Data Being Collected
```bash
# Check database permissions
ls -la /var/lib/netmon/

# Verify iptables rules
iptables -L -n | grep -E "(NFQUEUE|NFLOG)"

# Check daemon logs
tail -f /var/log/netmon/netmon.log
```

### Log Files

- **Service logs**: `/var/log/netmon/netmon.log`
- **System logs**: `logread | grep netmon`
- **Database**: `/var/lib/netmon/netmon.db`

## Uninstallation

To completely remove Network Monitor:

```bash
# Download and run uninstall script
wget -O - https://raw.githubusercontent.com/roni791158/Network-Monitor/main/uninstall.sh | sh

# Or if you have the source
./uninstall.sh
```

## Security Considerations

- Network Monitor operates with root privileges for packet capture
- All data is stored locally on the router
- Web interface uses router's authentication system
- No external data transmission
- Regular security updates recommended

## License

This project is licensed under the GPL-2.0 License - see the [LICENSE](LICENSE) file for details.

## Support

- **Issues**: [GitHub Issues](https://github.com/roni791158/Network-Monitor/issues)
- **Documentation**: [Wiki](https://github.com/roni791158/Network-Monitor/wiki)
- **Discussions**: [GitHub Discussions](https://github.com/roni791158/Network-Monitor/discussions)

## Changelog

### v1.0.0 (Initial Release)
- Real-time device monitoring
- Data usage tracking
- Website visit logging
- Modern web interface
- PDF report generation
- LuCI integration
- RESTful API

## Acknowledgments

- OpenWrt community for the excellent documentation
- Chart.js for beautiful data visualization
- SQLite for reliable data storage
- The open-source community for inspiration and support
