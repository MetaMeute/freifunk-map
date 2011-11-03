NodeMap = {}

function NodeMap:new ()
	o = {map = {}}
	setmetatable(o, self)
	self.__index = self
	return o
end

function NodeMap:addNodeWithId (id, coords)
	node = {id=id, coords=coords, status=nil, macs={}}
	self.map[id:lower()] = node
	return node
end

function NodeMap:getNode (id)
	return self.map[id:lower()]
end

function NodeMap:get ()
	return self.map	
end

function NodeMap:print ()
	print("NodeMap")
	for id, attrs in pairs(self.map) do
		print("  * " .. id)
		for k, v in pairs(attrs) do
			print("      " .. k .. ": " .. v)
		end 
	end
end

function NodeMap:toKML ()
	kml_template = "<Placemark><name>%s</name><styleUrl>#router-%s</styleUrl><Point><coordinates>%s,0</coordinates></Point><description>%s</description></Placemark>"
	kml = {}

	for id, attrs in pairs(self.map) do

		if attrs.status == "up" then
			status = "up"
		else
			status = "down"
		end

		if attrs.status == "unknown" then
			status = "unknown"
		end

		entry = kml_template:format(id, status, attrs.coords, describe_node(attrs))
		table.insert(kml, entry)
	end

	return table.concat(kml, "\n")
end

function describe_node (node)
	macs = {}
	for k, v in pairs(node.macs) do table.insert(macs, k) end
	return table.concat(macs, ", ")
end
