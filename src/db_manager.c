#include "netmon.h"

static sqlite3 *db = NULL;
static const char *DB_PATH = "/var/lib/netmon/netmon.db";

int init_database(void) {
    int rc = sqlite3_open(DB_PATH, &db);
    if (rc != SQLITE_OK) {
        fprintf(stderr, "Cannot open database: %s\n", sqlite3_errmsg(db));
        return -1;
    }
    
    // Create devices table
    const char *create_devices_sql = 
        "CREATE TABLE IF NOT EXISTS devices ("
        "id INTEGER PRIMARY KEY AUTOINCREMENT,"
        "ip TEXT UNIQUE NOT NULL,"
        "mac TEXT,"
        "hostname TEXT,"
        "first_seen INTEGER,"
        "last_seen INTEGER,"
        "is_active INTEGER DEFAULT 1"
        ");";
    
    // Create traffic table
    const char *create_traffic_sql =
        "CREATE TABLE IF NOT EXISTS traffic ("
        "id INTEGER PRIMARY KEY AUTOINCREMENT,"
        "ip TEXT NOT NULL,"
        "url TEXT,"
        "timestamp INTEGER,"
        "bytes_sent INTEGER,"
        "bytes_received INTEGER"
        ");";
    
    // Create indexes
    const char *create_index_sql[] = {
        "CREATE INDEX IF NOT EXISTS idx_devices_ip ON devices(ip);",
        "CREATE INDEX IF NOT EXISTS idx_traffic_ip ON traffic(ip);",
        "CREATE INDEX IF NOT EXISTS idx_traffic_timestamp ON traffic(timestamp);",
        NULL
    };
    
    char *err_msg = 0;
    
    // Execute table creation queries
    rc = sqlite3_exec(db, create_devices_sql, 0, 0, &err_msg);
    if (rc != SQLITE_OK) {
        fprintf(stderr, "SQL error: %s\n", err_msg);
        sqlite3_free(err_msg);
        return -1;
    }
    
    rc = sqlite3_exec(db, create_traffic_sql, 0, 0, &err_msg);
    if (rc != SQLITE_OK) {
        fprintf(stderr, "SQL error: %s\n", err_msg);
        sqlite3_free(err_msg);
        return -1;
    }
    
    // Create indexes
    for (int i = 0; create_index_sql[i] != NULL; i++) {
        rc = sqlite3_exec(db, create_index_sql[i], 0, 0, &err_msg);
        if (rc != SQLITE_OK) {
            fprintf(stderr, "SQL error: %s\n", err_msg);
            sqlite3_free(err_msg);
            return -1;
        }
    }
    
    return 0;
}

int add_device(device_t *device) {
    const char *sql = 
        "INSERT OR REPLACE INTO devices (ip, mac, hostname, first_seen, last_seen, is_active) "
        "VALUES (?, ?, ?, ?, ?, 1);";
    
    sqlite3_stmt *stmt;
    int rc = sqlite3_prepare_v2(db, sql, -1, &stmt, NULL);
    
    if (rc != SQLITE_OK) {
        fprintf(stderr, "Failed to prepare statement: %s\n", sqlite3_errmsg(db));
        return -1;
    }
    
    sqlite3_bind_text(stmt, 1, device->ip, -1, SQLITE_STATIC);
    sqlite3_bind_text(stmt, 2, device->mac, -1, SQLITE_STATIC);
    sqlite3_bind_text(stmt, 3, device->hostname, -1, SQLITE_STATIC);
    sqlite3_bind_int64(stmt, 4, device->first_seen);
    sqlite3_bind_int64(stmt, 5, device->last_seen);
    
    rc = sqlite3_step(stmt);
    sqlite3_finalize(stmt);
    
    if (rc != SQLITE_DONE) {
        fprintf(stderr, "Failed to insert device: %s\n", sqlite3_errmsg(db));
        return -1;
    }
    
    return 0;
}

int update_device_activity(const char *ip, time_t timestamp) {
    const char *sql = "UPDATE devices SET last_seen = ?, is_active = 1 WHERE ip = ?;";
    
    sqlite3_stmt *stmt;
    int rc = sqlite3_prepare_v2(db, sql, -1, &stmt, NULL);
    
    if (rc != SQLITE_OK) {
        fprintf(stderr, "Failed to prepare statement: %s\n", sqlite3_errmsg(db));
        return -1;
    }
    
    sqlite3_bind_int64(stmt, 1, timestamp);
    sqlite3_bind_text(stmt, 2, ip, -1, SQLITE_STATIC);
    
    rc = sqlite3_step(stmt);
    sqlite3_finalize(stmt);
    
    if (rc != SQLITE_DONE) {
        fprintf(stderr, "Failed to update device activity: %s\n", sqlite3_errmsg(db));
        return -1;
    }
    
    return 0;
}

int add_traffic_record(traffic_record_t *record) {
    const char *sql = 
        "INSERT INTO traffic (ip, url, timestamp, bytes_sent, bytes_received) "
        "VALUES (?, ?, ?, ?, ?);";
    
    sqlite3_stmt *stmt;
    int rc = sqlite3_prepare_v2(db, sql, -1, &stmt, NULL);
    
    if (rc != SQLITE_OK) {
        fprintf(stderr, "Failed to prepare statement: %s\n", sqlite3_errmsg(db));
        return -1;
    }
    
    sqlite3_bind_text(stmt, 1, record->ip, -1, SQLITE_STATIC);
    sqlite3_bind_text(stmt, 2, record->url, -1, SQLITE_STATIC);
    sqlite3_bind_int64(stmt, 3, record->timestamp);
    sqlite3_bind_int(stmt, 4, record->bytes_sent);
    sqlite3_bind_int(stmt, 5, record->bytes_received);
    
    rc = sqlite3_step(stmt);
    sqlite3_finalize(stmt);
    
    if (rc != SQLITE_DONE) {
        fprintf(stderr, "Failed to insert traffic record: %s\n", sqlite3_errmsg(db));
        return -1;
    }
    
    return 0;
}

int get_active_devices(device_t **devices, int *count) {
    const char *sql = "SELECT ip, mac, hostname, first_seen, last_seen FROM devices WHERE is_active = 1;";
    
    sqlite3_stmt *stmt;
    int rc = sqlite3_prepare_v2(db, sql, -1, &stmt, NULL);
    
    if (rc != SQLITE_OK) {
        fprintf(stderr, "Failed to prepare statement: %s\n", sqlite3_errmsg(db));
        return -1;
    }
    
    // Count rows first
    *count = 0;
    while (sqlite3_step(stmt) == SQLITE_ROW) {
        (*count)++;
    }
    
    sqlite3_reset(stmt);
    
    if (*count == 0) {
        sqlite3_finalize(stmt);
        *devices = NULL;
        return 0;
    }
    
    *devices = malloc(sizeof(device_t) * (*count));
    if (*devices == NULL) {
        sqlite3_finalize(stmt);
        return -1;
    }
    
    int i = 0;
    while (sqlite3_step(stmt) == SQLITE_ROW && i < *count) {
        const char *ip = (const char*)sqlite3_column_text(stmt, 0);
        const char *mac = (const char*)sqlite3_column_text(stmt, 1);
        const char *hostname = (const char*)sqlite3_column_text(stmt, 2);
        
        strncpy((*devices)[i].ip, ip ? ip : "", MAX_IP_LEN - 1);
        strncpy((*devices)[i].mac, mac ? mac : "", MAX_MAC_LEN - 1);
        strncpy((*devices)[i].hostname, hostname ? hostname : "", MAX_HOSTNAME_LEN - 1);
        (*devices)[i].first_seen = sqlite3_column_int64(stmt, 3);
        (*devices)[i].last_seen = sqlite3_column_int64(stmt, 4);
        (*devices)[i].is_active = 1;
        
        i++;
    }
    
    sqlite3_finalize(stmt);
    return 0;
}

int get_traffic_by_date(const char *start_date, const char *end_date, traffic_record_t **records, int *count) {
    const char *sql = 
        "SELECT ip, url, timestamp, bytes_sent, bytes_received FROM traffic "
        "WHERE timestamp BETWEEN strftime('%s', ?) AND strftime('%s', ?) "
        "ORDER BY timestamp DESC;";
    
    sqlite3_stmt *stmt;
    int rc = sqlite3_prepare_v2(db, sql, -1, &stmt, NULL);
    
    if (rc != SQLITE_OK) {
        fprintf(stderr, "Failed to prepare statement: %s\n", sqlite3_errmsg(db));
        return -1;
    }
    
    sqlite3_bind_text(stmt, 1, start_date, -1, SQLITE_STATIC);
    sqlite3_bind_text(stmt, 2, end_date, -1, SQLITE_STATIC);
    
    // Count rows first
    *count = 0;
    while (sqlite3_step(stmt) == SQLITE_ROW) {
        (*count)++;
    }
    
    sqlite3_reset(stmt);
    
    if (*count == 0) {
        sqlite3_finalize(stmt);
        *records = NULL;
        return 0;
    }
    
    *records = malloc(sizeof(traffic_record_t) * (*count));
    if (*records == NULL) {
        sqlite3_finalize(stmt);
        return -1;
    }
    
    int i = 0;
    while (sqlite3_step(stmt) == SQLITE_ROW && i < *count) {
        const char *ip = (const char*)sqlite3_column_text(stmt, 0);
        const char *url = (const char*)sqlite3_column_text(stmt, 1);
        
        strncpy((*records)[i].ip, ip ? ip : "", MAX_IP_LEN - 1);
        strncpy((*records)[i].url, url ? url : "", MAX_URL_LEN - 1);
        (*records)[i].timestamp = sqlite3_column_int64(stmt, 2);
        (*records)[i].bytes_sent = sqlite3_column_int(stmt, 3);
        (*records)[i].bytes_received = sqlite3_column_int(stmt, 4);
        
        i++;
    }
    
    sqlite3_finalize(stmt);
    return 0;
}

void cleanup_database(void) {
    if (db) {
        sqlite3_close(db);
        db = NULL;
    }
}
