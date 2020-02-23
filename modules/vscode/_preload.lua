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

	newaction {
		trigger     = "vscode",
		shortname   = "Visual Studio Code",
		description = "Generate Visual Studio Code workspace files",

		onWorkspace = function(wks)
			p.generate(wks, ".code-workspace", m.generateWorkspace)
		end,

		onProject = function(prj)
			-- NOTE: vscode projects have a fixed name and location that cannot be changed
			prj.location = path.join(prj.basedir, '.vscode')
			prj.filename = "settings"
			p.generate(prj, ".json", m.generateProject)
		end,
	}

--
-- Decide when the full module should be loaded.
--

	return function(cfg)
		return (_ACTION == "vscode")
	end
