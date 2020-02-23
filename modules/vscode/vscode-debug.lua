premake.modules.vscode.debug = {};
local d = premake.modules.vscode.debug

-- TODO: This isn't being loaded
print('vscode-debug loaded')

function table.print(t, recurse, depth, visited)
	local depth = depth or 0
	local indent = string.rep("  ", depth) -- TODO: Use tab

	local visited = visited or {}
	visited[t] = true

	local next = next
	for k, v in pairs(t) do
		if type(v) ~= "table" then
			io.write(indent, tostring(k))
			io.write(": ")
			io.write(tostring(v))
			io.write("\n")
		elseif recurse then
			if not visited[v] then
				local isEmpty = next(v) == nil
				if isEmpty then
					io.write(indent, tostring(k), ": {}\n")
				else
					io.write(indent, tostring(k), ": {\n")
					table.print(v, true, depth + 1, visited)
					io.write(indent, "}\n")
				end
			end
		end
	end
end

function table.dump(t, recurse, filename)
	local prevOutput = io.output()
	local file = io.open(filename, 'w')
	io.output(file)
	table.print(t, recurse)
	io.close(file)
	io.output(prevOutput)
end
