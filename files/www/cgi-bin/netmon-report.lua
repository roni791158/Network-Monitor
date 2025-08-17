#!/usr/bin/lua

local json = require "luci.json"
local sqlite3 = require "lsqlite3"
local os = require "os"
local io = require "io"

-- Database path
local DB_PATH = "/var/lib/netmon/netmon.db"
local REPORTS_DIR = "/tmp/netmon-reports"

-- Ensure reports directory exists
os.execute("mkdir -p " .. REPORTS_DIR)

-- Parse POST data
local content_length = tonumber(os.getenv("CONTENT_LENGTH")) or 0
local post_data = ""
if content_length > 0 then
    post_data = io.read(content_length)
end

local params = {}
if post_data ~= "" then
    local success, data = pcall(json.decode, post_data)
    if success then
        params = data
    end
end

-- Helper function to open database
local function open_db()
    local db = sqlite3.open(DB_PATH)
    if not db then
        return nil, "Failed to open database"
    end
    return db
end

-- Generate HTML report
local function generate_html_report(start_date, end_date, report_type)
    local db, err = open_db()
    if not db then
        return nil, err
    end
    
    -- Get data
    local devices = {}
    local traffic = {}
    local websites = {}
    
    -- Devices
    for row in db:nrows("SELECT ip, mac, hostname, first_seen, last_seen, is_active FROM devices ORDER BY last_seen DESC") do
        table.insert(devices, {
            ip = row.ip,
            mac = row.mac or "",
            hostname = row.hostname or "Unknown Device",
            first_seen = tonumber(row.first_seen) or 0,
            last_seen = tonumber(row.last_seen) or 0,
            is_active = (tonumber(row.is_active) or 0) == 1
        })
    end
    
    -- Traffic data
    local sql = string.format("SELECT ip, url, timestamp, bytes_sent, bytes_received FROM traffic WHERE timestamp BETWEEN strftime('%%s', '%s') AND strftime('%%s', '%s') ORDER BY timestamp DESC", start_date, end_date)
    for row in db:nrows(sql) do
        table.insert(traffic, {
            ip = row.ip,
            url = row.url or "",
            timestamp = tonumber(row.timestamp) or 0,
            bytes_sent = tonumber(row.bytes_sent) or 0,
            bytes_received = tonumber(row.bytes_received) or 0
        })
    end
    
    -- Website visits
    local website_sql = string.format("SELECT ip, url, timestamp, bytes_sent, bytes_received FROM traffic WHERE url IS NOT NULL AND url != '' AND timestamp BETWEEN strftime('%%s', '%s') AND strftime('%%s', '%s') ORDER BY timestamp DESC", start_date, end_date)
    for row in db:nrows(website_sql) do
        table.insert(websites, {
            ip = row.ip,
            url = row.url,
            timestamp = tonumber(row.timestamp) or 0,
            bytes_sent = tonumber(row.bytes_sent) or 0,
            bytes_received = tonumber(row.bytes_received) or 0
        })
    end
    
    db:close()
    
    -- Calculate statistics
    local total_download = 0
    local total_upload = 0
    local unique_websites = {}
    
    for _, record in ipairs(traffic) do
        total_download = total_download + record.bytes_received
        total_upload = total_upload + record.bytes_sent
    end
    
    for _, record in ipairs(websites) do
        unique_websites[record.url] = true
    end
    
    local website_count = 0
    for _ in pairs(unique_websites) do
        website_count = website_count + 1
    end
    
    -- Format bytes
    local function format_bytes(bytes)
        if bytes == 0 then return "0 B" end
        local k = 1024
        local sizes = {"B", "KB", "MB", "GB", "TB"}
        local i = math.floor(math.log(bytes) / math.log(k)) + 1
        if i > #sizes then i = #sizes end
        return string.format("%.2f %s", bytes / math.pow(k, i-1), sizes[i])
    end
    
    -- Format timestamp
    local function format_datetime(timestamp)
        return os.date("%Y-%m-%d %H:%M:%S", timestamp)
    end
    
    -- Generate HTML
    local html = [[
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Network Monitor Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { text-align: center; margin-bottom: 30px; }
        .stats { display: flex; justify-content: space-around; margin-bottom: 30px; }
        .stat-box { text-align: center; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .stat-number { font-size: 24px; font-weight: bold; color: #007bff; }
        table { width: 100%; border-collapse: collapse; margin-bottom: 30px; }
        th, td { padding: 10px; border: 1px solid #ddd; text-align: left; }
        th { background-color: #f8f9fa; }
        .section-title { font-size: 18px; font-weight: bold; margin: 20px 0 10px 0; }
        .footer { text-align: center; margin-top: 30px; font-size: 12px; color: #666; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Network Monitor Report</h1>
        <p>Period: ]] .. start_date .. [[ to ]] .. end_date .. [[</p>
        <p>Generated: ]] .. os.date("%Y-%m-%d %H:%M:%S") .. [[</p>
    </div>
    
    <div class="stats">
        <div class="stat-box">
            <div class="stat-number">]] .. #devices .. [[</div>
            <div>Total Devices</div>
        </div>
        <div class="stat-box">
            <div class="stat-number">]] .. format_bytes(total_download) .. [[</div>
            <div>Total Download</div>
        </div>
        <div class="stat-box">
            <div class="stat-number">]] .. format_bytes(total_upload) .. [[</div>
            <div>Total Upload</div>
        </div>
        <div class="stat-box">
            <div class="stat-number">]] .. website_count .. [[</div>
            <div>Unique Websites</div>
        </div>
    </div>
]]

    if report_type == "detailed" or report_type == "summary" then
        html = html .. [[
    <div class="section-title">Connected Devices</div>
    <table>
        <tr>
            <th>Device Name</th>
            <th>IP Address</th>
            <th>MAC Address</th>
            <th>Last Seen</th>
            <th>Status</th>
        </tr>
]]
        for _, device in ipairs(devices) do
            html = html .. string.format([[
        <tr>
            <td>%s</td>
            <td>%s</td>
            <td>%s</td>
            <td>%s</td>
            <td>%s</td>
        </tr>
]], device.hostname, device.ip, device.mac, format_datetime(device.last_seen), device.is_active and "Online" or "Offline")
        end
        html = html .. "    </table>\n"
    end

    if report_type == "detailed" then
        html = html .. [[
    <div class="section-title">Website Visits</div>
    <table>
        <tr>
            <th>Website</th>
            <th>Device IP</th>
            <th>Visit Time</th>
            <th>Data Transferred</th>
        </tr>
]]
        for i, website in ipairs(websites) do
            if i <= 100 then -- Limit to first 100 entries
                html = html .. string.format([[
        <tr>
            <td>%s</td>
            <td>%s</td>
            <td>%s</td>
            <td>%s</td>
        </tr>
]], website.url, website.ip, format_datetime(website.timestamp), format_bytes(website.bytes_sent + website.bytes_received))
            end
        end
        html = html .. "    </table>\n"
    end

    html = html .. [[
    <div class="footer">
        <p>Generated by Network Monitor v1.0.0</p>
    </div>
</body>
</html>
]]

    return html
end

-- Convert HTML to PDF using wkhtmltopdf (if available) or return HTML
local function generate_pdf_report(start_date, end_date, report_type)
    local html_content = generate_html_report(start_date, end_date, report_type)
    if not html_content then
        return nil, "Failed to generate HTML report"
    end
    
    local filename = string.format("network-report-%s-to-%s", start_date, end_date)
    local html_file = REPORTS_DIR .. "/" .. filename .. ".html"
    local pdf_file = REPORTS_DIR .. "/" .. filename .. ".pdf"
    
    -- Write HTML file
    local file = io.open(html_file, "w")
    if file then
        file:write(html_content)
        file:close()
    else
        return nil, "Failed to write HTML file"
    end
    
    -- Try to convert to PDF using wkhtmltopdf
    local pdf_cmd = string.format("wkhtmltopdf --page-size A4 --margin-top 0.75in --margin-right 0.75in --margin-bottom 0.75in --margin-left 0.75in %s %s 2>/dev/null", html_file, pdf_file)
    local success = os.execute(pdf_cmd)
    
    if success == 0 then
        -- PDF generated successfully
        return pdf_file, nil
    else
        -- Fall back to HTML
        return html_file, nil
    end
end

-- Main handler
local function handle_request()
    local start_date = params.start_date or ""
    local end_date = params.end_date or ""
    local report_type = params.report_type or "summary"
    
    if start_date == "" or end_date == "" then
        print("Content-Type: application/json\n")
        print(json.encode({ success = false, error = "Start date and end date are required" }))
        return
    end
    
    local report_file, err = generate_pdf_report(start_date, end_date, report_type)
    if not report_file then
        print("Content-Type: application/json\n")
        print(json.encode({ success = false, error = err or "Failed to generate report" }))
        return
    end
    
    -- Determine content type
    local content_type = "application/pdf"
    local filename = "network-report.pdf"
    
    if string.match(report_file, "%.html$") then
        content_type = "text/html"
        filename = "network-report.html"
    end
    
    -- Read and serve the file
    local file = io.open(report_file, "rb")
    if file then
        local content = file:read("*all")
        file:close()
        
        print("Content-Type: " .. content_type)
        print("Content-Disposition: attachment; filename=\"" .. filename .. "\"")
        print("Content-Length: " .. #content)
        print("")
        io.write(content)
        
        -- Clean up
        os.remove(report_file)
        if string.match(report_file, "%.pdf$") then
            os.remove(string.gsub(report_file, "%.pdf$", ".html"))
        end
    else
        print("Content-Type: application/json\n")
        print(json.encode({ success = false, error = "Failed to read report file" }))
    end
end

-- Execute
handle_request()
