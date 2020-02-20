--
-- Name:    vscode/_preload.lua
-- Purpose: Define the vscode action.
-- Author:  Adam Byrd
-- Created: 2020/02/19
--

	local p = premake

	print('vscode preloaded')

	newaction {
		trigger     = "vscode",
		shortname   = "Visual Studio Code",
		description = "Generate Visual Studio Code workspace files",

		--toolset         = "gcc",

		--valid_kinds     = { "ConsoleApp", "WindowedApp", "StaticLib", "SharedLib", "Utility", "Makefile" },

		--valid_languages = { "C", "C++", "C#" },

		--valid_tools     = {
		--	cc     = { "clang", "gcc" },
		--	dotnet = { "mono", "msnet", "pnet" }
		--},

		onInitialize = function() print("onInitialize") end,

		-- called first to indicate that processing has begun
		onStart = function() print("onStart") end,

		-- called once for every workspace that was declared
		onWorkspace = function(wks)
			printf("onWorkspace '%s'", wks.name)
			local m = p.modules.vscode
			p.generate(wks, ".wks.lua", m.generateWorkspace)
		end,

		onCleanWorkspace = function(wks) printf("onCleanWorkspace '%s'", wks.name) end,

		-- called once for every project that was declared
		onProject = function(prj)
			printf("onProject '%s'", prj.name)
			local m = p.modules.vscode
			p.generate(prj, ".prj.lua", m.generateProject)
		end,

		onCleanProject = function(prj) printf("onCleanProject '%s'", prj.name) end,

		-- called after all projects and workspaces have been processed
		execute = function() print("execute") end,

		-- called to indicate the processing is complete
		onEnd = function() print("onEnd") end,
	}

--
-- Decide when the full module should be loaded.
--

	return function(cfg)
		return (_ACTION == "vscode")
	end
