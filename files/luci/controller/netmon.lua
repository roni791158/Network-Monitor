module("luci.controller.netmon", package.seeall)

function index()
    entry({"admin", "network", "netmon"}, cbi("netmon"), _("Network Monitor"), 60).dependent = false
    entry({"admin", "network", "netmon", "status"}, call("action_status"), nil).leaf = true
end

function action_status()
    local http = require "luci.http"
    local json = require "luci.json"
    local uci = require "luci.model.uci".cursor()
    
    http.prepare_content("application/json")
    
    local result = {
        enabled = uci:get("netmon", "config", "enabled") == "1",
        interface = uci:get("netmon", "config", "interface") or "lan",
        log_level = uci:get("netmon", "config", "log_level") or "info",
        data_retention = uci:get("netmon", "config", "data_retention") or "30",
        update_interval = uci:get("netmon", "config", "update_interval") or "60",
        web_port = uci:get("netmon", "config", "web_port") or "8080"
    }
    
    http.write(json.encode(result))
end
