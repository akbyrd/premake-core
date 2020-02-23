--
-- Name:    vscode/_preload.lua
-- Purpose: Define the vscode action.
-- Author:  Adam Byrd
-- Created: 2020/02/19
--

	premake.modules.vscode = {};
	local m = premake.modules.vscode

	local p = premake

	m._VERSION = p._VERSION
	m.workspaceExt = ".code-workspace"
	m.projectName = "settings"
	m.projectExt = ".json"
	m.projectFilename = m.projectName .. m.projectExt

	newaction {
		trigger     = "vscode",
		shortname   = "Visual Studio Code",
		description = "Generate Visual Studio Code workspace files",

		onWorkspace = function(wks)
			p.generate(wks, m.workspaceExt, m.generateWorkspace)
		end,

		onProject = function(prj)
			p.generate(prj, m.projectFilename, m.generateProject)
		end,
	}

--
-- Decide when the full module should be loaded.
--

	return function(cfg)
		return (_ACTION == "vscode")
	end
