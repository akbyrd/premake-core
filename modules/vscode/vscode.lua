--
-- vscode.lua
--

	premake.modules.vscode = {};
	local m = premake.modules.vscode

	print('vscode loaded')
	m._VERSION = "1.0.0"

	local p = premake

	function m.generateWorkspace(wks)
		p.w('This is a Lua "workspace" file.')
	end


	function m.generateProject(prj)
		p.w('This is a Lua "project" file.')
	end

	return m
