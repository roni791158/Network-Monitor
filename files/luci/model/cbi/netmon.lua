local m, s, o

m = Map("netmon", translate("Network Monitor"), translate("Network monitoring configuration"))

s = m:section(TypedSection, "netmon", translate("General Settings"))
s.anonymous = true
s.addremove = false

o = s:option(Flag, "enabled", translate("Enable Network Monitor"))
o.default = "1"

o = s:option(Value, "interface", translate("Monitor Interface"))
o.default = "lan"
o:value("lan", "LAN")
o:value("wan", "WAN")
o:value("br-lan", "Bridge LAN")

o = s:option(ListValue, "log_level", translate("Log Level"))
o.default = "info"
o:value("debug", "Debug")
o:value("info", "Info")
o:value("warn", "Warning")
o:value("error", "Error")

o = s:option(Value, "data_retention", translate("Data Retention (days)"))
o.default = "30"
o.datatype = "uinteger"

o = s:option(Value, "update_interval", translate("Update Interval (seconds)"))
o.default = "60"
o.datatype = "uinteger"

o = s:option(Value, "web_port", translate("Web Interface Port"))
o.default = "8080"
o.datatype = "port"

return m
