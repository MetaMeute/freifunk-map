NodeMap = {map = {}}

-- aliases!

function NodeMap:new ()
	o = {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function NodeMap:addNodeWithId (id, coords)
	node = {coords=coords, status=nil}
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
	kml_template = "<Placemark><name>%s</name><styleUrl>#router-%s</styleUrl><Point><coordinates>%s,0</coordinates></Point></Placemark>"
	kml = {}

	kml_header = [[<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
<Document>
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

	table.insert(kml, kml_header)

	for id, attrs in pairs(self.map) do

		if attrs.status == "up" then
			status = "up"
		else
			status = "down"
		end

		entry = kml_template:format(id, status, attrs.coords)
		table.insert(kml, entry)
	end

	table.insert(kml, kml_footer)

	return table.concat(kml, "\n")
end
