#!/usr/bin/lua

require "nodemap"
require "Json"

function string:split(sep)
        local sep, fields = sep or ":", {}
        local pattern = string.format("([^%s]+)", sep)
        self:gsub(pattern, function(c) fields[#fields+1] = c end)
        return fields
end

macs = {}

nodes = NodeMap:new()

--nodes:addNodeWithId("8e:3d:c2:10:10:28", "10.69,53.8")
--nodes:addNodeWithId("e2:e5:9b:e6:69:29", "10.69,53.81")
--nodes:addNodeWithId("da:7b:6f:c1:63:c0", "10.702304,53.834384")

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
					for i, mac in ipairs(mac) do
						if i > #gps then
							node = nodes:addNodeWithId(mac, gps_format(gps[#gps]))
							node.macs[mac] = true
						end
					end
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

vis_data = {}

local f = io.popen("batctl vd json")
while true do
	local line = f:read("*l")
	if line == nil then break end

	t = Json.Decode(line)
	table.insert(vis_data, t)
end

node_map = nodes:get()
mac_map = {}

for j,x in pairs(node_map) do mac_map[j] = x end

for i, foo in pairs(vis_data) do
	if foo.gateway then
		node = mac_map[foo.gateway]
		if node then
			mac_map[foo.router:lower()] = node
			node.macs[foo.router:lower()] = true
		end
	end
end

--[[
for i, foo in pairs(vis_data) do
	if foo.label == "TT" then
		node = mac_map[foo.router:lower()]
		if node then
			mac_map[foo.gateway:lower()] = node
			node.macs[foo.gateway:lower()] = true
		end 
	end

	if foo.secondary then
		x = mac_map[foo.secondary:lower()]
		y = mac_map[foo.of:lower()]
		if x or y then
			node = x or y
			if x and y then print("found both?!") end
			mac_map[foo.of:lower()] = node
			mac_map[foo.secondary:lower()] = node
			node.macs[foo.of:lower()] = true
			node.macs[foo.secondary:lower()] = true
		end
	end
end
]]--

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
				link_map[key] = {x=mac_map[x], y=mac_map[y]}
			end
		end
	end
end

link_kml = {}
link_template = [[<Placemark> 
	<styleUrl>#wifi-link</styleUrl>
	<LineString>
		<coordinates>%s,0. %s,0.</coordinates>
	</LineString>
</Placemark>]]

for id, link in pairs(link_map) do
	table.insert(link_kml, link_template:format(link.x.coords, link.y.coords))
end

kml_links = table.concat(link_kml)

for id, node in pairs(nodes:get()) do
	if id:match("%x%x:%x%x:%x%x:%x%x:%x%x:%x%x") then
		if macs[id] then
			node.status = "up"
		end 
	end
end

kml_nodes = nodes:toKML()

kml_header = [[<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
<Document>
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
