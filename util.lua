function write_file (filename, strings)
	local fd = io.open(filename, "w+")
	for i, s in ipairs(strings) do
		fd:write(s)
	end
	fd:close()
end

