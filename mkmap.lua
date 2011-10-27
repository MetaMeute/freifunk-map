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
		node = node_map[foo.gateway]
		if node then
			mac_map[foo.router:lower()] = node
			mac_map[foo.gateway:lower()] = node
		end
	end
end

--[[
for i, foo in pairs(vis_data) do
	if foo.secondary then
		x = mac_map[foo.secondary:lower()]
		y = mac_map[foo.of:lower()]
		if x or y then
			node = x or y
			if x and y then print("found both?!") end
			mac_map[foo.of:lower()] = node
			mac_map[foo.secondary:lower()] = node
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
