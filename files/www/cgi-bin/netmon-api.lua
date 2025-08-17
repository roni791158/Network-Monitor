#!/usr/bin/lua

local json = require "luci.json"
local sqlite3 = require "lsqlite3"

-- Database path
local DB_PATH = "/var/lib/netmon/netmon.db"

-- Set content type
print("Content-Type: application/json\n")

-- Parse query string
local query_string = os.getenv("QUERY_STRING") or ""
local params = {}
for param in query_string:gmatch("([^&]+)") do
    local key, value = param:match("([^=]+)=([^=]*)")
    if key and value then
        params[key] = value:gsub("%%(%x%x)", function(hex)
            return string.char(tonumber(hex, 16))
        end)
    end
end

local action = params.action or "get_devices"

-- Helper function to open database
local function open_db()
    local db = sqlite3.open(DB_PATH)
    if not db then
        return nil, "Failed to open database"
    end
    return db
end

-- Helper function to format device data
local function format_device(row)
    return {
        ip = row[1],
        mac = row[2] or "",
        hostname = row[3] or "Unknown Device",
        first_seen = tonumber(row[4]) or 0,
        last_seen = tonumber(row[5]) or 0,
        is_active = (tonumber(row[6]) or 0) == 1
    }
end

-- Helper function to format traffic data
local function format_traffic(row)
    return {
        ip = row[1],
        url = row[2] or "",
        timestamp = tonumber(row[3]) or 0,
        bytes_sent = tonumber(row[4]) or 0,
        bytes_received = tonumber(row[5]) or 0
    }
end

-- Get connected devices
local function get_devices()
    local db, err = open_db()
    if not db then
        return { success = false, error = err }
    end
    
    local devices = {}
    local sql = "SELECT ip, mac, hostname, first_seen, last_seen, is_active FROM devices ORDER BY last_seen DESC"
    
    for row in db:nrows(sql) do
        table.insert(devices, {
            ip = row.ip,
            mac = row.mac or "",
            hostname = row.hostname or "Unknown Device",
            first_seen = tonumber(row.first_seen) or 0,
            last_seen = tonumber(row.last_seen) or 0,
            is_active = (tonumber(row.is_active) or 0) == 1
        })
    end
    
    db:close()
    return { success = true, devices = devices }
end

-- Get traffic data
local function get_traffic()
    local db, err = open_db()
    if not db then
        return { success = false, error = err }
    end
    
    local start_date = params.start_date or ""
    local end_date = params.end_date or ""
    local traffic = {}
    
    local sql
    if start_date ~= "" and end_date ~= "" then
        sql = string.format("SELECT ip, url, timestamp, bytes_sent, bytes_received FROM traffic WHERE timestamp BETWEEN strftime('%%s', '%s') AND strftime('%%s', '%s') ORDER BY timestamp DESC LIMIT 1000", start_date, end_date)
    else
        sql = "SELECT ip, url, timestamp, bytes_sent, bytes_received FROM traffic ORDER BY timestamp DESC LIMIT 1000"
    end
    
    for row in db:nrows(sql) do
        table.insert(traffic, {
            ip = row.ip,
            url = row.url or "",
            timestamp = tonumber(row.timestamp) or 0,
            bytes_sent = tonumber(row.bytes_sent) or 0,
            bytes_received = tonumber(row.bytes_received) or 0
        })
    end
    
    db:close()
    return { success = true, traffic = traffic }
end

-- Get website history
local function get_websites()
    local db, err = open_db()
    if not db then
        return { success = false, error = err }
    end
    
    local websites = {}
    local sql = "SELECT ip, url, timestamp, bytes_sent, bytes_received FROM traffic WHERE url IS NOT NULL AND url != '' ORDER BY timestamp DESC LIMIT 500"
    
    for row in db:nrows(sql) do
        table.insert(websites, {
            ip = row.ip,
            url = row.url,
            timestamp = tonumber(row.timestamp) or 0,
            bytes_sent = tonumber(row.bytes_sent) or 0,
            bytes_received = tonumber(row.bytes_received) or 0
        })
    end
    
    db:close()
    return { success = true, websites = websites }
end

-- Get statistics
local function get_stats()
    local db, err = open_db()
    if not db then
        return { success = false, error = err }
    end
    
    local stats = {
        active_devices = 0,
        total_download = 0,
        total_upload = 0,
        unique_websites = 0
    }
    
    -- Active devices
    for row in db:nrows("SELECT COUNT(*) as count FROM devices WHERE is_active = 1") do
        stats.active_devices = tonumber(row.count) or 0
    end
    
    -- Total traffic
    for row in db:nrows("SELECT SUM(bytes_sent) as upload, SUM(bytes_received) as download FROM traffic") do
        stats.total_upload = tonumber(row.upload) or 0
        stats.total_download = tonumber(row.download) or 0
    end
    
    -- Unique websites
    for row in db:nrows("SELECT COUNT(DISTINCT url) as count FROM traffic WHERE url IS NOT NULL AND url != ''") do
        stats.unique_websites = tonumber(row.count) or 0
    end
    
    db:close()
    return { success = true, stats = stats }
end

-- Main handler
local function handle_request()
    if action == "get_devices" then
        return get_devices()
    elseif action == "get_traffic" then
        return get_traffic()
    elseif action == "get_websites" then
        return get_websites()
    elseif action == "get_stats" then
        return get_stats()
    else
        return { success = false, error = "Unknown action: " .. action }
    end
end

-- Execute and return result
local result = handle_request()
print(json.encode(result))
