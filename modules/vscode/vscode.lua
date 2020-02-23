--
-- vscode.lua
--

	local m = premake.modules.vscode
	local d = premake.modules.vscode.debug

	local p = premake
	local tree = premake.tree
	local project = premake.project

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

	function m.cppOption(key, value)
		p.w(string.format('"C_Cpp.default.%s": %s,', key, value))
	end

	function m.cppOptionArray(key)
		p.push(string.format('"C_Cpp.default.%s": [', key))
	end

	function m.generateWorkspace(wks)
		p.push('{')
		p.push('"folders": [')
		local tr = p.workspace.grouptree(wks)
		tree.traverse(tr, {
			onleaf = function(n)
				local prj = n.project
				local path = m.relativePath(m.workspacePath(wks), m.projectScriptDir(prj))
				p.w('{ "path": "%s" },', path)
			end,
		})
		p.pop(']')
		p.pop('}')
		p.w('')
	end

	-- TODO: Deal with trailing commas (write to table, sort, then join)
	function m.generateProject(prj)
		p.push('{')
		if project.isc(prj) or project.iscpp(prj) then

			-- TODO: Does vscode suport multiple configurations outside of tasks?
			-- TODO: If not, add a way to choose the configuration
			local cfg = project.getfirstconfig(prj)

			m.cppOption('compileCommands',   'null')

			-- TODO: compilerArgs
			-- I guess everything going to the compiler?
			-- All compiler options not in file specific filters
			-- Relevant premake API: flags, warnings, optimize, ...
			--   First configuration, platform?
			m.cppOption('compilerArgs',      'null')

			m.cppOption('compilerPath',      'null')

			if     cfg.cppdialect == nil     then -- Emit nothing
			elseif cfg.cppdialect == 'C++98' then m.cppOption('cppStandard', 'c++98')
			elseif cfg.cppdialect == 'C++11' then m.cppOption('cppStandard', 'c++11')
			elseif cfg.cppdialect == 'C++14' then m.cppOption('cppStandard', 'c++14')
			elseif cfg.cppdialect == 'C++17' then m.cppOption('cppStandard', 'c++17')
			else
				p.warn('Unhandled cppdialect: %s', cfg.cppdialect)
			end

			if     cfg.cdialect == nil   then -- Emit nothing
			elseif cfg.cdialect == 'C89' then m.cppOption('cStandard', 'c89')
			elseif cfg.cdialect == 'C99' then m.cppOption('cStandard', 'c99')
			elseif cfg.cdialect == 'C11' then m.cppOption('cStandard', 'c11')
			else
				p.warn('Unhandled cdialect: %s', cfg.cdialect)
			end

			local defines = cfg.defines
			if #defines > 0 then
				m.cppOptionArray('defines')
				for i = 1, #defines do
					p.w('"%s",', defines[i])
				end
				p.pop('],')
			end

			-- TODO: User extensibility
			m.cppOption('forcedInclude', 'null')

			-- TODO: Need system includes if we don't have compilerPath
			local includeDirs = cfg.includeDirs
			if #includeDirs > 0 then
				m.cppOptionArray('includePath')
				for i = 1, #includeDirs do
					p.w('"%s",', m.relativePath(m.projectPath(prj), includeDirs[i]))
				end
				p.pop('],')
			end

			local vtoolset
			if     cfg.toolset == nil     then -- Emit nothing
			elseif cfg.toolset:startswith('clang') then vtoolset = 'clang'
			elseif cfg.toolset:startswith('gcc')   then vtoolset = 'gcc'
			elseif cfg.toolset:startswith('msc')   then vtoolset = 'msvc'
			else
				p.warn('Unhandled toolset: %s', cfg.toolset)
			end

			local varchitecture
			if     cfg.architecture == nil      then -- Emit nothing
			elseif cfg.architecture == 'x86'    then varchitecture = 'x86'
			elseif cfg.architecture == 'x86_64' then varchitecture = 'x64'
			else
				p.warn('Unhandled architecture: %s', cfg.architecture)
			end

			if vtoolset and varchitecture then
				m.cppOption('intelliSenseMode', string.format('"%s-%s"', vtoolset, varchitecture))
			end

			if #cfg.frameworkdirs > 0 then
				m.cppOptionArray('macFrameworkPath')
				for i = 1, #cfg.frameworkdirs do
					p.w('"%s",', m.relativePath(m.projectPath(prj), cfg.frameworkdirs[i]))
				end
				p.pop('],')
			end

			m.cppOption('systemIncludePath', 'null')
			m.cppOption('windowsSdkVersion', 'null')
		end
		p.pop('}')
		p.w('')
	end

	return m
