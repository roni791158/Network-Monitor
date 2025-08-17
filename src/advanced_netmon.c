#include "netmon.h"
#include <linux/netfilter.h>
#include <linux/netfilter_ipv4.h>
#include <netinet/ip.h>
#include <netinet/tcp.h>
#include <netinet/udp.h>
#include <sys/time.h>
#include <pcap.h>

// Advanced monitoring structures
typedef struct {
    char ip[MAX_IP_LEN];
    char mac[MAX_MAC_LEN];
    char hostname[MAX_HOSTNAME_LEN];
    uint64_t bytes_in;
    uint64_t bytes_out;
    uint64_t packets_in;
    uint64_t packets_out;
    double speed_in_mbps;
    double speed_out_mbps;
    time_t last_seen;
    time_t speed_calc_time;
    int is_blocked;
    int speed_limit_kbps;
    int is_active;
} advanced_device_t;

typedef struct {
    char device_ip[MAX_IP_LEN];
    char website[MAX_URL_LEN];
    char domain[256];
    time_t timestamp;
    int port;
    char protocol[16];
    uint32_t bytes_transferred;
} website_visit_t;

typedef struct {
    char ip[MAX_IP_LEN];
    uint64_t prev_bytes_in;
    uint64_t prev_bytes_out;
    time_t prev_time;
    uint64_t curr_bytes_in;
    uint64_t curr_bytes_out;
    time_t curr_time;
} speed_tracker_t;

// Global variables
static advanced_device_t devices[256];
static int device_count = 0;
static speed_tracker_t speed_trackers[256];
static int tracker_count = 0;

// Function prototypes
int init_advanced_monitoring(void);
int update_device_stats(const char *ip, const char *mac, uint64_t bytes_in, uint64_t bytes_out);
double calculate_speed(const char *ip, uint64_t bytes, int direction);
int log_website_visit(const char *ip, const char *domain, int port, const char *protocol);
int apply_speed_limit(const char *ip, int limit_kbps);
int block_device(const char *ip, int block);
int get_live_device_stats(advanced_device_t **device_list, int *count);

// Initialize advanced monitoring
int init_advanced_monitoring(void) {
    memset(devices, 0, sizeof(devices));
    memset(speed_trackers, 0, sizeof(speed_trackers));
    device_count = 0;
    tracker_count = 0;
    
    // Initialize database with advanced tables
    if (init_database() != 0) {
        return -1;
    }
    
    // Create advanced monitoring tables
    const char *create_advanced_devices_sql = 
        "CREATE TABLE IF NOT EXISTS advanced_devices ("
        "id INTEGER PRIMARY KEY AUTOINCREMENT,"
        "ip TEXT UNIQUE NOT NULL,"
        "mac TEXT,"
        "hostname TEXT,"
        "bytes_in INTEGER DEFAULT 0,"
        "bytes_out INTEGER DEFAULT 0,"
        "packets_in INTEGER DEFAULT 0,"
        "packets_out INTEGER DEFAULT 0,"
        "speed_in_mbps REAL DEFAULT 0,"
        "speed_out_mbps REAL DEFAULT 0,"
        "last_seen INTEGER,"
        "is_blocked INTEGER DEFAULT 0,"
        "speed_limit_kbps INTEGER DEFAULT 0,"
        "is_active INTEGER DEFAULT 1"
        ");";
    
    const char *create_website_visits_sql =
        "CREATE TABLE IF NOT EXISTS website_visits ("
        "id INTEGER PRIMARY KEY AUTOINCREMENT,"
        "device_ip TEXT NOT NULL,"
        "website TEXT,"
        "domain TEXT,"
        "timestamp INTEGER,"
        "port INTEGER,"
        "protocol TEXT,"
        "bytes_transferred INTEGER"
        ");";
    
    const char *create_speed_history_sql =
        "CREATE TABLE IF NOT EXISTS speed_history ("
        "id INTEGER PRIMARY KEY AUTOINCREMENT,"
        "device_ip TEXT NOT NULL,"
        "timestamp INTEGER,"
        "speed_in_mbps REAL,"
        "speed_out_mbps REAL,"
        "bytes_in INTEGER,"
        "bytes_out INTEGER"
        ");";
    
    sqlite3 *db;
    char *err_msg = 0;
    int rc = sqlite3_open("/var/lib/netmon/netmon.db", &db);
    
    if (rc != SQLITE_OK) {
        return -1;
    }
    
    // Execute table creation
    rc = sqlite3_exec(db, create_advanced_devices_sql, 0, 0, &err_msg);
    if (rc != SQLITE_OK) {
        sqlite3_free(err_msg);
        sqlite3_close(db);
        return -1;
    }
    
    rc = sqlite3_exec(db, create_website_visits_sql, 0, 0, &err_msg);
    if (rc != SQLITE_OK) {
        sqlite3_free(err_msg);
        sqlite3_close(db);
        return -1;
    }
    
    rc = sqlite3_exec(db, create_speed_history_sql, 0, 0, &err_msg);
    if (rc != SQLITE_OK) {
        sqlite3_free(err_msg);
        sqlite3_close(db);
        return -1;
    }
    
    sqlite3_close(db);
    return 0;
}

// Update device statistics
int update_device_stats(const char *ip, const char *mac, uint64_t bytes_in, uint64_t bytes_out) {
    int device_index = -1;
    
    // Find existing device or create new one
    for (int i = 0; i < device_count; i++) {
        if (strcmp(devices[i].ip, ip) == 0) {
            device_index = i;
            break;
        }
    }
    
    if (device_index == -1 && device_count < 256) {
        device_index = device_count++;
        strncpy(devices[device_index].ip, ip, MAX_IP_LEN - 1);
        strncpy(devices[device_index].mac, mac, MAX_MAC_LEN - 1);
        
        // Try to resolve hostname
        char *hostname = resolve_hostname(ip);
        if (hostname) {
            strncpy(devices[device_index].hostname, hostname, MAX_HOSTNAME_LEN - 1);
            free(hostname);
        } else {
            snprintf(devices[device_index].hostname, MAX_HOSTNAME_LEN, "Device-%s", ip + strlen(ip) - 3);
        }
    }
    
    if (device_index >= 0) {
        // Calculate speed
        double speed_in = calculate_speed(ip, bytes_in, 0);
        double speed_out = calculate_speed(ip, bytes_out, 1);
        
        // Update device stats
        devices[device_index].bytes_in += bytes_in;
        devices[device_index].bytes_out += bytes_out;
        devices[device_index].packets_in++;
        devices[device_index].packets_out++;
        devices[device_index].speed_in_mbps = speed_in;
        devices[device_index].speed_out_mbps = speed_out;
        devices[device_index].last_seen = time(NULL);
        devices[device_index].is_active = 1;
        
        // Update database
        sqlite3 *db;
        int rc = sqlite3_open("/var/lib/netmon/netmon.db", &db);
        if (rc == SQLITE_OK) {
            const char *sql = 
                "INSERT OR REPLACE INTO advanced_devices "
                "(ip, mac, hostname, bytes_in, bytes_out, packets_in, packets_out, "
                "speed_in_mbps, speed_out_mbps, last_seen, is_active) "
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);";
            
            sqlite3_stmt *stmt;
            rc = sqlite3_prepare_v2(db, sql, -1, &stmt, NULL);
            if (rc == SQLITE_OK) {
                sqlite3_bind_text(stmt, 1, devices[device_index].ip, -1, SQLITE_STATIC);
                sqlite3_bind_text(stmt, 2, devices[device_index].mac, -1, SQLITE_STATIC);
                sqlite3_bind_text(stmt, 3, devices[device_index].hostname, -1, SQLITE_STATIC);
                sqlite3_bind_int64(stmt, 4, devices[device_index].bytes_in);
                sqlite3_bind_int64(stmt, 5, devices[device_index].bytes_out);
                sqlite3_bind_int64(stmt, 6, devices[device_index].packets_in);
                sqlite3_bind_int64(stmt, 7, devices[device_index].packets_out);
                sqlite3_bind_double(stmt, 8, devices[device_index].speed_in_mbps);
                sqlite3_bind_double(stmt, 9, devices[device_index].speed_out_mbps);
                sqlite3_bind_int64(stmt, 10, devices[device_index].last_seen);
                sqlite3_bind_int(stmt, 11, devices[device_index].is_active);
                
                sqlite3_step(stmt);
                sqlite3_finalize(stmt);
            }
            sqlite3_close(db);
        }
        
        // Log speed history
        if (speed_in > 0 || speed_out > 0) {
            sqlite3_open("/var/lib/netmon/netmon.db", &db);
            if (rc == SQLITE_OK) {
                const char *speed_sql = 
                    "INSERT INTO speed_history (device_ip, timestamp, speed_in_mbps, speed_out_mbps, bytes_in, bytes_out) "
                    "VALUES (?, ?, ?, ?, ?, ?);";
                
                sqlite3_stmt *stmt;
                rc = sqlite3_prepare_v2(db, speed_sql, -1, &stmt, NULL);
                if (rc == SQLITE_OK) {
                    sqlite3_bind_text(stmt, 1, ip, -1, SQLITE_STATIC);
                    sqlite3_bind_int64(stmt, 2, time(NULL));
                    sqlite3_bind_double(stmt, 3, speed_in);
                    sqlite3_bind_double(stmt, 4, speed_out);
                    sqlite3_bind_int64(stmt, 5, bytes_in);
                    sqlite3_bind_int64(stmt, 6, bytes_out);
                    
                    sqlite3_step(stmt);
                    sqlite3_finalize(stmt);
                }
                sqlite3_close(db);
            }
        }
    }
    
    return 0;
}

// Calculate network speed
double calculate_speed(const char *ip, uint64_t bytes, int direction) {
    int tracker_index = -1;
    time_t current_time = time(NULL);
    
    // Find existing tracker
    for (int i = 0; i < tracker_count; i++) {
        if (strcmp(speed_trackers[i].ip, ip) == 0) {
            tracker_index = i;
            break;
        }
    }
    
    if (tracker_index == -1 && tracker_count < 256) {
        tracker_index = tracker_count++;
        strncpy(speed_trackers[tracker_index].ip, ip, MAX_IP_LEN - 1);
        speed_trackers[tracker_index].prev_time = current_time;
        return 0.0;
    }
    
    if (tracker_index >= 0) {
        speed_tracker_t *tracker = &speed_trackers[tracker_index];
        
        uint64_t prev_bytes = direction == 0 ? tracker->prev_bytes_in : tracker->prev_bytes_out;
        uint64_t curr_bytes = direction == 0 ? tracker->curr_bytes_in + bytes : tracker->curr_bytes_out + bytes;
        
        if (direction == 0) {
            tracker->curr_bytes_in += bytes;
        } else {
            tracker->curr_bytes_out += bytes;
        }
        
        tracker->curr_time = current_time;
        
        // Calculate speed if we have previous data
        if (tracker->prev_time > 0 && (current_time - tracker->prev_time) >= 1) {
            uint64_t bytes_diff = curr_bytes - prev_bytes;
            time_t time_diff = current_time - tracker->prev_time;
            
            if (time_diff > 0) {
                double speed_bps = (double)bytes_diff / time_diff;
                double speed_mbps = speed_bps / (1024.0 * 1024.0) * 8.0; // Convert to Mbps
                
                // Update tracker for next calculation
                if (direction == 0) {
                    tracker->prev_bytes_in = tracker->curr_bytes_in;
                } else {
                    tracker->prev_bytes_out = tracker->curr_bytes_out;
                }
                tracker->prev_time = current_time;
                
                return speed_mbps;
            }
        }
    }
    
    return 0.0;
}

// Log website visit
int log_website_visit(const char *ip, const char *domain, int port, const char *protocol) {
    sqlite3 *db;
    int rc = sqlite3_open("/var/lib/netmon/netmon.db", &db);
    
    if (rc != SQLITE_OK) {
        return -1;
    }
    
    const char *sql = 
        "INSERT INTO website_visits (device_ip, domain, timestamp, port, protocol) "
        "VALUES (?, ?, ?, ?, ?);";
    
    sqlite3_stmt *stmt;
    rc = sqlite3_prepare_v2(db, sql, -1, &stmt, NULL);
    
    if (rc == SQLITE_OK) {
        sqlite3_bind_text(stmt, 1, ip, -1, SQLITE_STATIC);
        sqlite3_bind_text(stmt, 2, domain, -1, SQLITE_STATIC);
        sqlite3_bind_int64(stmt, 3, time(NULL));
        sqlite3_bind_int(stmt, 4, port);
        sqlite3_bind_text(stmt, 5, protocol, -1, SQLITE_STATIC);
        
        sqlite3_step(stmt);
        sqlite3_finalize(stmt);
    }
    
    sqlite3_close(db);
    return rc == SQLITE_OK ? 0 : -1;
}

// Apply speed limit to device
int apply_speed_limit(const char *ip, int limit_kbps) {
    // Use tc (traffic control) to limit bandwidth
    char cmd[512];
    
    if (limit_kbps > 0) {
        // Create speed limit
        snprintf(cmd, sizeof(cmd), 
            "tc qdisc add dev br-lan root handle 1: htb default 10 && "
            "tc class add dev br-lan parent 1: classid 1:1 htb rate 100mbit && "
            "tc class add dev br-lan parent 1:1 classid 1:10 htb rate %dkbit ceil %dkbit && "
            "tc filter add dev br-lan protocol ip parent 1:0 prio 1 u32 match ip dst %s flowid 1:10",
            limit_kbps, limit_kbps, ip);
    } else {
        // Remove speed limit
        snprintf(cmd, sizeof(cmd), "tc qdisc del dev br-lan root 2>/dev/null");
    }
    
    int result = system(cmd);
    
    // Update database
    sqlite3 *db;
    int rc = sqlite3_open("/var/lib/netmon/netmon.db", &db);
    if (rc == SQLITE_OK) {
        const char *sql = "UPDATE advanced_devices SET speed_limit_kbps = ? WHERE ip = ?;";
        sqlite3_stmt *stmt;
        rc = sqlite3_prepare_v2(db, sql, -1, &stmt, NULL);
        if (rc == SQLITE_OK) {
            sqlite3_bind_int(stmt, 1, limit_kbps);
            sqlite3_bind_text(stmt, 2, ip, -1, SQLITE_STATIC);
            sqlite3_step(stmt);
            sqlite3_finalize(stmt);
        }
        sqlite3_close(db);
    }
    
    return result == 0 ? 0 : -1;
}

// Block/unblock device
int block_device(const char *ip, int block) {
    char cmd[256];
    
    if (block) {
        // Block device using iptables
        snprintf(cmd, sizeof(cmd), 
            "iptables -I FORWARD -s %s -j DROP && iptables -I FORWARD -d %s -j DROP", 
            ip, ip);
    } else {
        // Unblock device
        snprintf(cmd, sizeof(cmd), 
            "iptables -D FORWARD -s %s -j DROP 2>/dev/null; iptables -D FORWARD -d %s -j DROP 2>/dev/null", 
            ip, ip);
    }
    
    int result = system(cmd);
    
    // Update database
    sqlite3 *db;
    int rc = sqlite3_open("/var/lib/netmon/netmon.db", &db);
    if (rc == SQLITE_OK) {
        const char *sql = "UPDATE advanced_devices SET is_blocked = ? WHERE ip = ?;";
        sqlite3_stmt *stmt;
        rc = sqlite3_prepare_v2(db, sql, -1, &stmt, NULL);
        if (rc == SQLITE_OK) {
            sqlite3_bind_int(stmt, 1, block ? 1 : 0);
            sqlite3_bind_text(stmt, 2, ip, -1, SQLITE_STATIC);
            sqlite3_step(stmt);
            sqlite3_finalize(stmt);
        }
        sqlite3_close(db);
    }
    
    return result == 0 ? 0 : -1;
}

// Get live device statistics
int get_live_device_stats(advanced_device_t **device_list, int *count) {
    *device_list = malloc(sizeof(advanced_device_t) * device_count);
    if (*device_list == NULL) {
        return -1;
    }
    
    memcpy(*device_list, devices, sizeof(advanced_device_t) * device_count);
    *count = device_count;
    
    return 0;
}
