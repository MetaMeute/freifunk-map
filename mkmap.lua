#!/usr/bin/lua

require "nodemap"

function string:split(sep)
        local sep, fields = sep or ":", {}
        local pattern = string.format("([^%s]+)", sep)
        self:gsub(pattern, function(c) fields[#fields+1] = c end)
        return fields
end

macs = {}

nodes = NodeMap:new()

local f = io.popen("wget -q --user-agent 'Do not change this!' -O- 'http://10.130.0.8/meutewiki/Freifunk/Knoten?action=raw'")

local table_index = {}

function gps_format (x)
	return x:gsub("^%s+", ""):gsub("%s+$", ""):gsub("(.*) (.*)", "%2,%1")
end

while true do
	local line = f:read("*l")
	if line == nil then break end
	if line:find("^||") then
		if next(table_index) == nil then
			local i = 1
			for k in line:lower():gsub("'''", ""):gsub(" ", ""):gmatch("||([^\|]+)") do
				table_index[k] = i
				i = i + 1
			end
		else
			local row = line:lower():split("||")
			local gps = row[table_index['gps']]
			local mac = row[table_index['mac']]:gsub(" ", ""):split(",")
			if gps:match("^%s+$") == nil then
				for i, coords in ipairs(gps:split(",")) do
					coords = gps_format(coords)

					node_mac = mac[i]
					if node_mac then
						node_id = node_mac
					else
						node_id = coords
					end

					nodes:addNodeWithId(node_id, coords)
				end
			end
		end
	end
end

local f = io.popen("batctl tl")
while true do
	local line = f:read("*l")
	if line == nil then break end
	mac = line:match("%x%x:%x%x:%x%x:%x%x:%x%x:%x%x")
	if mac then 
		macs[mac:lower()] = true
	end
end

local f = io.popen("batctl tg")
while true do
	local line = f:read("*l")
	if line == nil then break end
	mac = line:match("via %x%x:%x%x:%x%x:%x%x:%x%x:%x%x")
	if mac then 
		macs[mac:sub(5):lower()] = true
	end
end


for id, node in pairs(nodes:get()) do
	if id:match("%x%x:%x%x:%x%x:%x%x:%x%x:%x%x") then
		if macs[id] then
			node.status = "up"
		end 
	end
end

kml = nodes:toKML()
print(kml)
