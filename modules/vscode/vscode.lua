--
-- vscode.lua
--

	local m = premake.modules.vscode

	local p = premake
	local tree = premake.tree

	m._VERSION = "1.0.0"

	function m.workspacePath(wks)
		return premake.filename(wks, m.workspaceExt)
	end

	function m.projectPath(prj)
		return premake.filename(prj, m.projectFilename)
	end

	function m.projectScriptDir(prj)
		return prj.basedir
	end

	function m.relativePath(from, to)
		return path.getrelative(path.getdirectory(from), to)
	end

	function m.generateWorkspace(wks)
		p.push("{")
		p.push("\"folders\": [")
		local tr = p.workspace.grouptree(wks)
		tree.traverse(tr, {
			onleaf = function(n)
				local prj = n.project
				local path = m.relativePath(m.workspacePath(wks), m.projectScriptDir(prj))
				p.w("{ \"path\": \"%s\" },", path)
			end,
		})
		p.pop("]")
		p.pop("}")
	end

	function m.generateProject(prj)
	end

	return m
