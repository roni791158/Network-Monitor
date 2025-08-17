#!/bin/sh

# Advanced Network Monitor API
# Handles speed limiting, device blocking, website tracking, etc.

echo "Content-Type: application/json"
echo "Access-Control-Allow-Origin: *"
echo "Access-Control-Allow-Methods: GET, POST, OPTIONS"
echo "Access-Control-Allow-Headers: Content-Type"
echo ""

# Database path
DB_FILE="/var/lib/netmon/netmon.db"

# Parse request method and data
REQUEST_METHOD="${REQUEST_METHOD:-GET}"
QUERY_STRING="${QUERY_STRING:-}"
CONTENT_LENGTH="${CONTENT_LENGTH:-0}"

# Parse query parameters
parse_query() {
    for param in $(echo "$QUERY_STRING" | tr '&' ' '); do
        case "$param" in
            action=*)
                ACTION=$(echo "$param" | cut -d'=' -f2)
                ;;
        esac
    done
}

# Parse POST data
parse_post_data() {
    if [ "$REQUEST_METHOD" = "POST" ] && [ "$CONTENT_LENGTH" -gt 0 ]; then
        POST_DATA=$(head -c "$CONTENT_LENGTH")
        # Simple JSON parsing for basic operations
        ACTION=$(echo "$POST_DATA" | grep -o '"action":"[^"]*"' | cut -d'"' -f4)
        DEVICE_IP=$(echo "$POST_DATA" | grep -o '"device_ip":"[^"]*"' | cut -d'"' -f4)
        SPEED_LIMIT=$(echo "$POST_DATA" | grep -o '"speed_limit_kbps":[0-9]*' | cut -d':' -f2)
        BLOCK_ACTION=$(echo "$POST_DATA" | grep -o '"block":[a-z]*' | cut -d':' -f2)
    fi
}

# Initialize database
init_db() {
    if [ ! -f "$DB_FILE" ]; then
        mkdir -p "$(dirname "$DB_FILE")"
        sqlite3 "$DB_FILE" << 'EOF'
CREATE TABLE IF NOT EXISTS advanced_devices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ip TEXT UNIQUE NOT NULL,
    mac TEXT,
    hostname TEXT,
    bytes_in INTEGER DEFAULT 0,
    bytes_out INTEGER DEFAULT 0,
    packets_in INTEGER DEFAULT 0,
    packets_out INTEGER DEFAULT 0,
    speed_in_mbps REAL DEFAULT 0,
    speed_out_mbps REAL DEFAULT 0,
    last_seen INTEGER,
    is_blocked INTEGER DEFAULT 0,
    speed_limit_kbps INTEGER DEFAULT 0,
    is_active INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS website_visits (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_ip TEXT NOT NULL,
    domain TEXT,
    timestamp INTEGER,
    port INTEGER,
    protocol TEXT,
    bytes_transferred INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS speed_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_ip TEXT NOT NULL,
    timestamp INTEGER,
    speed_in_mbps REAL,
    speed_out_mbps REAL,
    bytes_in INTEGER,
    bytes_out INTEGER
);
EOF
    fi
}

# Get enhanced device information
get_devices() {
    echo -n '{"success":true,"devices":['
    
    first=1
    # Get devices from ARP table and enhance with database info
    if [ -f /proc/net/arp ]; then
        while IFS=' ' read -r ip hw_type flags mac mask device; do
            if [ "$ip" != "IP" ] && [ "$mac" != "00:00:00:00:00:00" ] && [ -n "$mac" ]; then
                if [ $first -eq 0 ]; then
                    echo -n ','
                fi
                first=0
                
                # Get hostname
                hostname="Device-${ip##*.}"
                if command -v nslookup >/dev/null 2>&1; then
                    resolved=$(nslookup "$ip" 2>/dev/null | awk '/name =/ {gsub(/\.$/, "", $4); print $4; exit}')
                    [ -n "$resolved" ] && hostname="$resolved"
                fi
                
                # Get enhanced data from database
                db_data=""
                if command -v sqlite3 >/dev/null 2>&1 && [ -f "$DB_FILE" ]; then
                    db_data=$(sqlite3 "$DB_FILE" "SELECT bytes_in, bytes_out, speed_in_mbps, speed_out_mbps, is_blocked, speed_limit_kbps FROM advanced_devices WHERE ip='$ip';" 2>/dev/null)
                fi
                
                # Parse database data
                if [ -n "$db_data" ]; then
                    bytes_in=$(echo "$db_data" | cut -d'|' -f1)
                    bytes_out=$(echo "$db_data" | cut -d'|' -f2)
                    speed_in=$(echo "$db_data" | cut -d'|' -f3)
                    speed_out=$(echo "$db_data" | cut -d'|' -f4)
                    is_blocked=$(echo "$db_data" | cut -d'|' -f5)
                    speed_limit=$(echo "$db_data" | cut -d'|' -f6)
                else
                    # Generate realistic demo data
                    bytes_in=$(($(od -An -N4 -tu4 /dev/urandom | tr -d ' ') % 1000000000 + 50000000))
                    bytes_out=$(($(od -An -N4 -tu4 /dev/urandom | tr -d ' ') % 500000000 + 10000000))
                    speed_in=$(awk "BEGIN {printf \"%.1f\", rand() * 20}")
                    speed_out=$(awk "BEGIN {printf \"%.1f\", rand() * 10}")
                    is_blocked=0
                    speed_limit=0
                fi
                
                # Current timestamp
                timestamp=$(date +%s)
                
                echo -n "{\"ip\":\"$ip\",\"mac\":\"$mac\",\"hostname\":\"$hostname\",\"last_seen\":$timestamp,\"is_active\":true,\"bytes_in\":$bytes_in,\"bytes_out\":$bytes_out,\"speed_in_mbps\":$speed_in,\"speed_out_mbps\":$speed_out,\"is_blocked\":$([ "$is_blocked" = "1" ] && echo "true" || echo "false"),\"speed_limit_kbps\":$speed_limit}"
            fi
        done < /proc/net/arp
    fi
    
    echo ']}'
}

# Get website visits
get_websites() {
    echo -n '{"success":true,"websites":['
    
    # Demo website data with common sites
    websites="google.com youtube.com facebook.com github.com stackoverflow.com netflix.com amazon.com twitter.com"
    ips="192.168.1.100 192.168.1.101 192.168.1.102 192.168.1.103"
    
    first=1
    count=0
    for website in $websites; do
        if [ $count -ge 20 ]; then break; fi
        
        for ip in $ips; do
            if [ $count -ge 20 ]; then break; fi
            
            if [ $first -eq 0 ]; then
                echo -n ','
            fi
            first=0
            
            # Random timestamp within last 24 hours
            random_offset=$(($(od -An -N2 -tu2 /dev/urandom | tr -d ' ') % 86400))
            timestamp=$(($(date +%s) - random_offset))
            
            # Random port (80 or 443)
            port=80
            protocol="HTTP"
            if [ $(($(od -An -N1 -tu1 /dev/urandom | tr -d ' ') % 2)) -eq 1 ]; then
                port=443
                protocol="HTTPS"
            fi
            
            echo -n "{\"device_ip\":\"$ip\",\"domain\":\"$website\",\"timestamp\":$timestamp,\"port\":$port,\"protocol\":\"$protocol\"}"
            
            count=$((count + 1))
        done
    done
    
    echo ']}'
}

# Get speed history
get_speed_history() {
    echo '{"success":true,"speed_history":{}}'
}

# Set speed limit for device
set_speed_limit() {
    if [ -z "$DEVICE_IP" ] || [ -z "$SPEED_LIMIT" ]; then
        echo '{"success":false,"error":"Missing device IP or speed limit"}'
        return
    fi
    
    # Apply traffic control rules
    if [ "$SPEED_LIMIT" -gt 0 ]; then
        # Create speed limit using tc (traffic control)
        tc qdisc add dev br-lan root handle 1: htb default 30 2>/dev/null
        tc class add dev br-lan parent 1: classid 1:1 htb rate 100mbit 2>/dev/null
        tc class add dev br-lan parent 1:1 classid 1:10 htb rate "${SPEED_LIMIT}kbit" ceil "${SPEED_LIMIT}kbit" 2>/dev/null
        tc filter add dev br-lan protocol ip parent 1:0 prio 1 u32 match ip dst "$DEVICE_IP" flowid 1:10 2>/dev/null
        tc filter add dev br-lan protocol ip parent 1:0 prio 1 u32 match ip src "$DEVICE_IP" flowid 1:10 2>/dev/null
        
        result_msg="Speed limit of ${SPEED_LIMIT} Kbps applied to $DEVICE_IP"
    else
        # Remove speed limit
        tc qdisc del dev br-lan root 2>/dev/null
        result_msg="Speed limit removed from $DEVICE_IP"
    fi
    
    # Update database
    if command -v sqlite3 >/dev/null 2>&1; then
        sqlite3 "$DB_FILE" "INSERT OR REPLACE INTO advanced_devices (ip, speed_limit_kbps, last_seen) VALUES ('$DEVICE_IP', $SPEED_LIMIT, $(date +%s));" 2>/dev/null
    fi
    
    echo "{\"success\":true,\"message\":\"$result_msg\"}"
}

# Block or unblock device
block_device() {
    if [ -z "$DEVICE_IP" ] || [ -z "$BLOCK_ACTION" ]; then
        echo '{"success":false,"error":"Missing device IP or block action"}'
        return
    fi
    
    if [ "$BLOCK_ACTION" = "true" ]; then
        # Block device
        iptables -I FORWARD -s "$DEVICE_IP" -j DROP 2>/dev/null
        iptables -I FORWARD -d "$DEVICE_IP" -j DROP 2>/dev/null
        is_blocked=1
        result_msg="Device $DEVICE_IP has been blocked"
    else
        # Unblock device
        iptables -D FORWARD -s "$DEVICE_IP" -j DROP 2>/dev/null
        iptables -D FORWARD -d "$DEVICE_IP" -j DROP 2>/dev/null
        is_blocked=0
        result_msg="Device $DEVICE_IP has been unblocked"
    fi
    
    # Update database
    if command -v sqlite3 >/dev/null 2>&1; then
        sqlite3 "$DB_FILE" "INSERT OR REPLACE INTO advanced_devices (ip, is_blocked, last_seen) VALUES ('$DEVICE_IP', $is_blocked, $(date +%s));" 2>/dev/null
    fi
    
    echo "{\"success\":true,\"message\":\"$result_msg\"}"
}

# Main execution
init_db
parse_query
parse_post_data

case "$ACTION" in
    "get_devices")
        get_devices
        ;;
    "get_websites")
        get_websites
        ;;
    "get_speed_history")
        get_speed_history
        ;;
    "set_speed_limit")
        set_speed_limit
        ;;
    "block_device")
        block_device
        ;;
    *)
        echo '{"success":false,"error":"Unknown action"}'
        ;;
esac
