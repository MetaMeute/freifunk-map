#!/usr/bin/lua

require "nodemap"
require "Json"

function string:split(sep)
        local sep, fields = sep or ":", {}
        local pattern = string.format("([^%s]+)", sep)
        self:gsub(pattern, function(c) fields[#fields+1] = c end)
        return fields
end

nodes = NodeMap:new()

--[[
node = nodes:addNodeWithId("intracity (virtual)", "10.68792,53.85944")
node.macs["8e:3d:c2:10:10:28"] = true
node.macs["e2:e5:9b:e6:69:29"] = true
node.macs["da:7b:6f:c1:63:c0"] = true
node.macs["56:47:05:ab:00:2c"] = true
node.macs["04:11:6b:98:08:21"] = true
node.status = "virtual"
]]--

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
				gps = gps:split(",")
				for i, coords in ipairs(gps) do
					coords = gps_format(coords)

					node_mac = mac[i]
					if node_mac then
						node_id = node_mac
					else
						node_id = coords
					end

					node = nodes:addNodeWithId(node_id, coords)
					if node_mac then node.macs[node_mac] = true end
				end
				if #gps < #mac then
					for i, m in ipairs(mac) do
						if i > #gps then
							node = nodes:getNode(mac[#gps])
							node.macs[m] = true
						end
					end
				end
			end
		end
	end
end

vis_data = {}

local f = io.popen("batctl vd json")
while true do
	local line = f:read("*l")
	if line == nil then break end

	t = Json.Decode(line)
	table.insert(vis_data, t)
end

mac_map = {}

for j, node in pairs(nodes:get()) do 
	for m, y in pairs(node.macs) do
		mac_map[m] = node
	end
end

-- add macs of routers to known gateways --
--[[
for i, foo in pairs(vis_data) do
	if foo.gateway then
		node = mac_map[foo.gateway:lower()]
		if node then
			router = foo.router:lower()
			mac_map[router] = node
			node.macs[router] = true
		end
	end
end
]]--

unknown_x = 10.65
unknown_y = 53.827
count = 0

-- find secondary macs for known nodes --
for i, foo in pairs(vis_data) do
	if foo.secondary then
		x = mac_map[foo.secondary:lower()]
		y = mac_map[foo.of:lower()]
		if x or y then
			if x and y then print("found both?!") end

			node = x or y
			mac_map[foo.of:lower()] = node
			mac_map[foo.secondary:lower()] = node
			node.macs[foo.of:lower()] = true
			node.macs[foo.secondary:lower()] = true
		end
	end
end

-- build list of nodes --
local f = io.popen("batctl o")
while true do
	local line = f:read("*l")
	if line == nil then break end
	mac = line:match("^%x%x:%x%x:%x%x:%x%x:%x%x:%x%x")
	if mac then 
		mac = mac:lower()
	else
		if line:match("MainIF") then
			mac = line:match("%x%x:%x%x:%x%x:%x%x:%x%x:%x%x")
			if mac then
				mac = mac:lower()
			end
		end
	end

	if mac then
		if mac_map[mac] then
			 mac_map[mac].status = "up"
		else 
			x = unknown_x + count * 0.005
			y = unknown_y + math.mod(count, 2) * 0.005
			node = nodes:addNodeWithId(mac, x .. "," .. y)
			node.macs[mac] = true
			node.status = "up"
			mac_map[mac] = node
			count = count + 1
		end 
	end
end

-- find secondary macs for known nodes --
for i, foo in pairs(vis_data) do
	if foo.secondary then
		x = mac_map[foo.secondary:lower()]
		y = mac_map[foo.of:lower()]
		if x or y then
			if x and y then break end

			node = x or y
			mac_map[foo.of:lower()] = node
			mac_map[foo.secondary:lower()] = node
			node.macs[foo.of:lower()] = true
			node.macs[foo.secondary:lower()] = true
		end
	end
end

-- find clients --
-- should use batctl tg instead! --
for i, foo in pairs(vis_data) do
	if foo.label == "TT" then
--		node = mac_map[foo.router:lower()]
--		if node then
--			node.clients[foo.gateway:lower()] = true
--		end 
	end
end

link_map = {}

for i, foo in pairs(vis_data) do
	if foo.neighbor then
		x = foo.router:lower()
		y = foo.neighbor:lower()
		if mac_map[x] and mac_map[y] then
			key = {x, y}
			table.sort(key)
			key = table.concat(key)

			if link_map[key] == nil then
				if mac_map[x].status == "virtual" or mac_map[y].status == "virtual" then
					link_type = "virtual-link"
				else
					link_type = "wifi-link"
				end
				link_map[key] = {x=mac_map[x], y=mac_map[y], label=foo.label, type=link_type}
			end
		end
	end
end

link_kml = {}
link_template = [[<Placemark> 
	<LineString>
		<coordinates>%s,0. %s,0.</coordinates>
	</LineString>
	<description>%s</description>
	<styleUrl>#%s</styleUrl>
	<name>%s</name>
</Placemark>]]

for id, link in pairs(link_map) do
	table.insert(link_kml, link_template:format(link.x.coords, link.y.coords, link.label, link.type, link.type))
end

kml_links = table.concat(link_kml)

kml_nodes = nodes:toKML()

kml_header = [[<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
<Document>
	<Style id="virtual-link">
		<LineStyle>
			<color>#4f0013f8</color>
			<width>2</width>
		</LineStyle> 
	</Style>
	<Style id="wifi-link">
		<LineStyle>
			<color>#ff13d854</color>
			<width>4</width>
		</LineStyle> 
	</Style>
	<Style id="router-up">
		<IconStyle>
			<Icon>
				<href>router-up.png</href>
				<scale>1.0</scale>
			</Icon>
		</IconStyle>
	</Style>
	<Style id="router-down">
		<IconStyle>
			<Icon>
				<href>router-down.png</href>
				<scale>1.0</scale>
			</Icon>
		</IconStyle>
	</Style>]]

kml_footer = [[</Document></kml>]]

print(kml_header)
print(kml_links)
print(kml_nodes)
print(kml_footer)
