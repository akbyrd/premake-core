--
-- vscode.lua
--

	local m = premake.modules.vscode
	local d = premake.modules.vscode.debug

	local p = premake
	local tree = premake.tree
	local project = premake.project

	-- TODO: Why don't project and workspace.getrelative work?

	function m.cppOption(key, value)
		p.w(string.format('"C_Cpp.default.%s": %s,', key, value))
	end

	function m.cppOptionArray(key)
		p.push(string.format('"C_Cpp.default.%s": [', key))
	end

	function m.option(key, value)
		p.w(string.format('"%s": %s,', key, value))
	end

	function m.optionArray(key)
		p.push(string.format('"%s": [', key))
	end

	function m.optionTable(key)
		p.push(string.format('"%s": {', key))
	end

	function m.generateWorkspace(wks)
		p.push('{')

		p.push('"folders": [')
		local tr = p.workspace.grouptree(wks)
		tree.traverse(tr, {
			onleaf = function(n)
				local prj = n.project
				local path = path.getrelative(wks.location, prj.basedir)
				p.w('{ "path": "%s" },', path)
			end,
		})
		p.pop('],')
		p.outln('')

		-- TODO: The same files.exlude problem exists here as below. Likely need to migrate the
		-- exclude settings to any project they happen to be under.
		m.optionTable('settings')
		m.optionTable('files.exclude')
			local scriptDir = path.getdirectory(wks.script)
			if wks.location ~= scriptDir then
				p.w('"%s": true,', '.')
			end
		p.pop('},')
		p.pop('},')

		p.pop('}')
		p.outln('')
	end

	function m.generateProject(prj)
		-- TODO: Does vscode suport multiple configurations outside of tasks?
		-- TODO: If not, add a way to choose the configuration
		local cfg = project.getconfig(prj)

		p.push('{')
		if project.isc(prj) or project.iscpp(prj) then
			-- TODO: This approach doesn't support per-file options. Perhaps compileCommands is better
			-- for that reason?
			m.cppOptionArray('compilerArgs')
			-- TODO: This default should come from a secondary action option
			local toolset = p.tools[cfg.toolset or 'msc']
			local cppflags = toolset.getcppflags(cfg)
			for i = 1, #cppflags do
				p.w('"%s",', cppflags[i])
			end
			local cflags = toolset.getcflags(cfg)
			for i = 1, #cflags do
				p.w('"%s",', cflags[i])
			end
			for i = 1, #cfg.buildoptions do
				p.w('"%s",', cfg.buildoptions[i])
			end
			p.pop('],')

			-- TODO: I don't think premake knows this
			--m.cppOption('compilerPath', 'null')

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

			if #cfg.defines > 0 then
				m.cppOptionArray('defines')
				for i = 1, #cfg.defines do
					p.w('"%s",', cfg.defines[i])
				end
				p.pop('],')
			end

			if #cfg.forceincludes > 0 then
				m.cppOptionArray('forcedInclude')
				for i = 1, #cfg.forceincludes do
					p.w('"%s",', path.getrelative(prj.basedir, cfg.forceincludes[i]))
				end
				p.pop('],')
			end

			if #cfg.includeDirs > 0 then
				m.cppOptionArray('includePath')
				for i = 1, #cfg.includeDirs do
					p.w('"%s",', path.getrelative(prj.basedir, cfg.includeDirs[i]))
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
					p.w('"%s",', path.getrelative(prj.basedir, cfg.frameworkdirs[i]))
				end
				p.pop('],')
			end

			-- TODO: Need system includes if we don't have compilerPath
			m.cppOption('systemIncludePath', 'null')

			local minsystemversion
			if _ACTION:startswith('vs') then
				local vstudio = require('vstudio')
				minsystemversion = vstudio.vc2010.targetPlatformVersion(prj)
			end
			if not minsystemversion then
				minsystemversion = project.systemversion(prj)
			end
			if minsystemversion then
				m.cppOption('windowsSdkVersion', string.format('"%s"', minsystemversion))
			end
			p.outln('')
		end

		-- TODO: files.exclude doesn't work when a project outputs to a folder outside of itself (e.g.
		-- luasocket outputs to premake-core/bin which is ../../bin). Perhaps we should check for this
		-- and hoist the ignore to either the workspace or the project the output ends up under.
		m.optionTable('files.exclude')
		for cfg in project.eachconfig(prj) do
			if cfg.targetdir then
				p.w('"%s": true,', path.getrelative(prj.basedir, cfg.targetdir))
			else
				p.w('"%s": true,', path.getrelative(prj.basedir, path.join(cfg.location, 'bin')))
			end

			if prj.objdir then
				p.w('"%s": true,', path.getrelative(prj.basedir, prj.objdir))
			else
				p.w('"%s": true,', path.getrelative(prj.basedir, path.join(cfg.location, 'obj')))
			end
		end
		p.pop('},')

		p.pop('}')
		p.outln('')
	end

	return m
