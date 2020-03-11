--
-- vscode.lua
--

	local m = premake.modules.vscode
	local debug = premake.modules.vscode.debug
	local build = premake.modules.vscode.build
	local emit = premake.modules.vscode.emit

	local p = premake
	local tree = premake.tree
	local project = premake.project

--
-- Various functions for gathering and building the data that
-- will later be emitted to vscode project files
--

	function build.root(ctx)
		local t = {}
		t.type = 'object'
		t.values = {}

		ctx.t = t
		return t
	end

	function build.primitive(ctx, key, value)
		local sortKey = key or value
		if not ctx.t.values[sortKey] then
			ctx.t.values[sortKey] = value

			local primitive = {}
			primitive.type = 'primitive'
			primitive.key = key
			primitive.value = value
			primitive.sortKey = sortKey
			table.insert(ctx.t.values, primitive)
		end
		return ctx.t.values[sortKey]
	end

	function build.pushObject(ctx, key)
		local object = {}
		object.type = 'object'
		object.key = key
		object.values = {}
		object.parent = ctx.t
		object.sortKey = key
		table.insert(ctx.t.values, object)
		ctx.t = object
		return object
	end

	function build.pushArray(ctx, key)
		local array = {}
		array.type = 'array'
		array.key = key
		array.values = {}
		array.parent = ctx.t
		array.sortKey = key
		table.insert(ctx.t.values, array)
		ctx.t = array
		return array
	end

	function build.pop(ctx)
		ctx.t = ctx.t.parent
	end

--
-- Various functions for emitting vscode project files
--

	local indentLevel = 0

	function emit.jsonEscaper(str)
		str = string.gsub(str, '\\', '\\\\')
		str = string.gsub(str, '"', '\\"')
		return str
	end

	function emit.text(ctx, ...)
		p.out(string.format(...))
	end

	function emit.indent(ctx)
		if not ctx.indented then
			ctx.indented = true
			emit.text(ctx, string.rep('\t', indentLevel))
		else
			emit.text(ctx, ' ')
		end
	end

	function emit.newline(ctx)
		if not ctx.singleLine then
			ctx.indented = false
			emit.text(ctx, '\n')
		end
	end

	function emit.push(ctx, ...)
		emit.indent(ctx)
		emit.text(ctx, ...)
		emit.newline(ctx)
		indentLevel = indentLevel + 1
	end

	function emit.pop(ctx, ...)
		indentLevel = indentLevel - 1
		emit.newline(ctx)
		emit.indent(ctx)
		emit.text(ctx, ...)
	end

	function emit.table(t)
		local ctx = {}
		ctx.stack = {}
		emit.pushKeyValue(ctx, t)
		emit.value(ctx)
		emit.popKeyValue(ctx)
		-- TODO: Looks like premake trims a single trailing newline?
		emit.newline(ctx)
		emit.newline(ctx)
	end

	function emit.pushKeyValue(ctx, t)
		ctx.t = t
		table.insert(ctx.stack, ctx.singleLine)
		ctx.singleLine = ctx.singleLine or t.singleLine or (t.values and #t.values == 0)
	end

	function emit.popKeyValue(ctx)
		ctx.t = nil -- HACK
		ctx.singleLine = table.remove(ctx.stack)
	end

	function emit.key(ctx)
		emit.indent(ctx)
		emit.text(ctx, '"%s":', ctx.t.key)
	end

	function emit.primitive(ctx)
		emit.indent(ctx)
		if type(ctx.t.value) == 'nil' then
			emit.text(ctx, 'null')
		elseif type(ctx.t.value) == 'string' then
			emit.text(ctx, '"%s"', p.esc(ctx.t.value))
		else
			emit.text(ctx, '%s', ctx.t.value)
		end
	end

	function emit.object(ctx)
		local t = ctx.t

		if t.sort ~= false then
			table.sort(t.values, function (a, b)
				return a.sortKey < b.sortKey
			end)
		end

		emit.push(ctx, '{')
		for i = 1, #t.values do
			emit.pushKeyValue(ctx, t.values[i])
			emit.key(ctx)
			emit.value(ctx)
			emit.popKeyValue(ctx)
			if i ~= #t.values then
				emit.text(ctx, ',')
				emit.newline(ctx)
			end
		end
		emit.pop(ctx, '}')
	end

	function emit.array(ctx)
		local t = ctx.t

		if t.sort ~= false then
			table.sort(t.values, function (a, b)
				return a.sortKey < b.sortKey
			end)
		end

		emit.push(ctx, '[')
		for i = 1, #t.values do
			emit.pushKeyValue(ctx, t.values[i])
			emit.value(ctx)
			emit.popKeyValue(ctx)
			if i ~= #t.values then
				emit.text(ctx, ',')
				emit.newline(ctx)
			end
		end
		emit.pop(ctx, ']')
	end

	function emit.value(ctx)
		local t = ctx.t

		if t.type == 'primitive' then
			emit.primitive(ctx)

		elseif t.type == 'object' then
			emit.object(ctx)

		elseif t.type == 'array' then
			emit.array(ctx)

		else
			assert(false, string.format('table "%s" has invalid type "%s"', t.key, t.type))
		end
	end

--
-- Implementations of the vscode action callbacks
--

	function m.generateWorkspace(wks)
		local ctx = {}
		local t = build.root(ctx)
		ctx.t.sort = false

		build.pushArray(ctx, 'folders')
		local tr = p.workspace.grouptree(wks)
		tree.traverse(tr, {
			onleaf = function(n)
				local prj = n.project
				local path = path.getrelative(wks.location, prj.basedir)
				build.pushObject(ctx, nil)
				ctx.t.sort = false
				ctx.t.sortKey = path
				ctx.t.singleLine = true
				build.primitive(ctx, 'path', path)
				build.primitive(ctx, 'name', prj.name)
				build.pop(ctx)
			end,
		})
		build.pop(ctx)

		-- TODO: The same files.exclude problem exists here as below. Likely need to migrate the
		-- exclude settings to any project they happen to be under.
		build.pushObject(ctx, 'settings')
		build.pushObject(ctx, 'files.exclude')
		local scriptDir = path.getdirectory(wks.script)
		if wks.location ~= scriptDir then
			build.primitive(ctx, '.', true)
		end
		build.pop(ctx)
		build.pop(ctx)

		build.pushObject(ctx, 'extensions')
		build.pushArray(ctx, 'recommendations')
		local tr = p.workspace.grouptree(wks)
		build.primitive(ctx, nil, 'keyring.lua')
		tree.traverse(tr, {
			onleaf = function(n)
				local prj = n.project
				if project.isc(prj) or project.iscpp(prj) then
					build.primitive(ctx, nil, 'ms-vscode.cpptools')
				end
			end,
		})
		build.pop(ctx)
		build.pop(ctx)

		emit.table(t)
	end

	function m.generateProject(prj)
		-- TODO: Does vscode suport multiple configurations outside of tasks?
		-- TODO: If not, add a way to choose the configuration
		local cfg = project.getconfig(prj)

		local ctx = {}
		local t = build.root(ctx)
		ctx.t.sort = false

		if project.isc(prj) or project.iscpp(prj) then
			-- TODO: This approach doesn't support per-file options. Perhaps compileCommands is better
			-- for that reason?
			build.pushArray(ctx, 'C_Cpp.default.compilerArgs')
			-- TODO: This default should come from a secondary action option
			local toolset = p.tools[cfg.toolset or 'msc']
			local cppflags = toolset.getcppflags(cfg)
			for i = 1, #cppflags do
				build.primitive(ctx, nil, cppflags[i])
			end
			local cflags = toolset.getcflags(cfg)
			for i = 1, #cflags do
				build.primitive(ctx, nil, cflags[i])
			end
			for i = 1, #cfg.buildoptions do
				build.primitive(ctx, nil, cfg.buildoptions[i])
			end
			build.pop(ctx)
		end

		-- TODO: I don't think premake knows this
		--build.primitive(ctx, 'C_Cpp.default.compilerPath', nil)

		-- TODO: Data drive this
		local key = 'C_Cpp.default.cppStandard'
		if     cfg.cppdialect == nil     then -- Emit nothing
		elseif cfg.cppdialect == 'C++98' then build.primitive(ctx, key, 'c++98')
		elseif cfg.cppdialect == 'C++11' then build.primitive(ctx, key, 'c++11')
		elseif cfg.cppdialect == 'C++14' then build.primitive(ctx, key, 'c++14')
		elseif cfg.cppdialect == 'C++17' then build.primitive(ctx, key, 'c++17')
		else
			p.warn('Unhandled cppdialect: %s', cfg.cppdialect)
		end

		local key = 'C_Cpp.default.cStandard'
		if     cfg.cdialect == nil   then -- Emit nothing
		elseif cfg.cdialect == 'C89' then build.primitive(ctx, key, 'c89')
		elseif cfg.cdialect == 'C99' then build.primitive(ctx, key, 'c99')
		elseif cfg.cdialect == 'C11' then build.primitive(ctx, key, 'c11')
		else
			p.warn('Unhandled cdialect: %s', cfg.cdialect)
		end

		if #cfg.defines > 0 then
			build.pushArray(ctx, 'C_Cpp.default.defines')
			for i = 1, #cfg.defines do
				build.primitive(ctx, nil, cfg.defines[i])
			end
			build.pop(ctx)
		end

		if #cfg.forceincludes > 0 then
			build.pushArray(ctx, 'C_Cpp.default.forcedInclude')
			for i = 1, #cfg.forceincludes do
				build.primitive(ctx, nil, path.getrelative(prj.basedir, cfg.forceincludes[i]))
			end
			build.pop(ctx)
		end

		if #cfg.includeDirs > 0 then
			build.pushArray(ctx, 'C_Cpp.default.includePath')
			for i = 1, #cfg.includeDirs do
				build.primitive(ctx, nil, path.getrelative(prj.basedir, cfg.includeDirs[i]))
			end
			build.pop(ctx)
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
			local intelliSenseMode = string.format('%s-%s', vtoolset, varchitecture)
			build.primitive(ctx, 'C_Cpp.default.intelliSenseMode', intelliSenseMode)
		end

		if #cfg.frameworkdirs > 0 then
			build.pushArray(ctx, 'C_Cpp.default.macFrameworkPath')
			for i = 1, #cfg.frameworkdirs do
				build.primitive(ctx, path.getrelative(prj.basedir, cfg.frameworkdirs[i]))
			end
			build.pop(ctx)
		end

		-- TODO: Need system includes if we don't have compilerPath
		--build.primitive(ctx, 'C_Cpp.default.systemIncludePath', nil)

		local minsystemversion
		if _ACTION:startswith('vs') then
			local vstudio = require('vstudio')
			minsystemversion = vstudio.vc2010.targetPlatformVersion(prj)
		end
		if not minsystemversion then
			minsystemversion = project.systemversion(prj)
		end
		if minsystemversion then
			build.primitive(ctx, 'C_Cpp.default.windowsSdkVersion', minsystemversion)
		end

		-- TODO: files.exclude doesn't work when a project outputs to a folder outside of itself (e.g.
		-- luasocket outputs to premake-core/bin which is ../../bin). Perhaps we should check for this
		-- and hoist the ignore to either the workspace or the project the output ends up under.
		-- TODO: Why do we have to consider the default here? Does baking not handle this?
		build.pushObject(ctx, 'files.exclude')
		for cfg in project.eachconfig(prj) do
			local targetDir = cfg.targetdir or path.join(cfg.location, 'bin')
			build.primitive(ctx, path.getrelative(prj.basedir, targetDir), true)

			local objDir = prj.objdir or path.join(cfg.location, 'obj')
			build.primitive(ctx, path.getrelative(prj.basedir, objDir), true)
		end
		build.pop(ctx)

		emit.table(t)
	end

	function m.generateLaunch(prj)
		local ctx = {}
		local t = build.root(ctx)
		ctx.t.sort = false

		-- TODO: Don't emit if empty
		build.primitive(ctx, 'version', '0.2.0')
		build.pushArray(ctx, 'configurations')
		ctx.t.sort = false

		-- TODO: vscode only supports these platforms. Can we check this at a higher level?
		if cfg.system == p.WINDOWS or cfg.system == p.LINUX or cfg.system == p.MACOSX then
			if project.isc(prj) or project.iscpp(prj) then
				for cfg in project.eachconfig(prj) do
					-- HACK: Skip anything that doesn't have an application to run.
					if cfg.debugcommand or prj.kind == p.CONSOLEAPP or prj.kind == p.WINDOWEDAPP then
						build.pushObject(ctx, nil)
						ctx.t.sort = false

						build.primitive(ctx, 'name', string.format('Launch %s (%s)', prj.name, cfg.name))

						local type = cfg.system == p.WINDOWS and 'cppvsdbg' or 'cppdbg'
						build.primitive(ctx, 'type', type)

						build.primitive(ctx, 'request', 'launch')

						local cwd = path.getrelative(prj.baseDir, cfg.debugdir or '.')
						build.primitive(ctx, 'cwd', path.join(string.format('${workspaceFolder:%s}', prj.name), cwd))

						if cfg.debugcommand then
							build.primitive(ctx, 'program', cfg.debugcommand)
						elseif prj.kind == p.CONSOLEAPP or prj.kind == p.WINDOWEDAPP then
							local cwdFull = path.join(prj.baseDir, cwd)
							build.primitive(ctx, 'program', path.getrelative(cwdFull, cfg.buildtarget.fullpath))
						end

						if #cfg.debugargs > 0 then
							build.pushArray(ctx, 'args')
							for i = 1, #cfg.debugargs do
								build.primitive(ctx, nil, cfg.debugargs[i])
							end
							build.pop(ctx)
						end

						if #cfg.debugenvs > 0 then
							build.pushArray(ctx, 'environment')
							ctx.t.sort = false
							for i = 1, #cfg.debugenvs do
								local var, value = table.unpack(string.explode(cfg.debugenvs[i], '=', true, 2))
								build.pushObject(ctx, nil)
								ctx.t.singleLine = true
								build.primitive(ctx, var, value)
								build.pop(ctx)
							end
							build.pop(ctx)
						end

						-- TODO: Extensibility
						--build.primitive(ctx, 'stopAtEntry', false)
						--build.primitive(ctx, 'externalConsole', false)
						--logging
						--visualizerFile

						build.pop(ctx)
					end
				end
			end
		end

		build.pop(ctx)

		emit.table(t)
	end

	return m
