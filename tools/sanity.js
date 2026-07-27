const fs = require('fs');
const path = require('path');
const childProcess = require('child_process');

const projectRoot = path.join(__dirname, '..');
const compiledRoot = path.join(projectRoot, 'dest', 'lua');
const panelFixtureRoot = path.join(__dirname, 'fixtures', 'panels');
const generatedPanelFixtures = path.join(projectRoot, 'dest', 'test', 'panel_fixtures.lua');

const allowedPrivateMethodCalls = new Set(['__setCoordinates']);
const precedenceTraps = [
	[/math_abs\([^)]*(?:<=|>=|==|~=|<|>)[^)]*\)/, 'Suspicious math_abs call around a comparison'],
	[/IsEntity\([^)]*IsValid/, 'Suspicious IsEntity/IsValid precedence'],
	[/IsFocused\([^)]*\band\b/, 'Suspicious IsFocused argument precedence'],
	[/\b\w+\.socketGet(?:SocketType|X|Y)\s*\(/, 'Socket method invoked on its owning node instead of node.socket'],
];

function walk(dir, files = []) {
	for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
		const fullPath = path.join(dir, entry.name);
		if (entry.isDirectory()) walk(fullPath, files);
		else if (entry.isFile() && entry.name.endsWith('.lua')) files.push(fullPath);
	}
	return files;
}

function addFailure(failures, file, message) {
	failures.push(`${file}: ${message}`);
}

function requirePattern(failures, file, source, pattern, message) {
	if (!pattern.test(source)) addFailure(failures, file, message);
}

function forbidPattern(failures, file, source, pattern, message) {
	if (pattern.test(source)) addFailure(failures, file, message);
}

function requireAll(failures, file, source, patterns, message) {
	if (patterns.some((pattern) => !pattern.test(source))) addFailure(failures, file, message);
}

/*
 * These checks intentionally inspect compiled Lua. They guard against
 * compiler-output regressions that ordinary Lua tests cannot see, but keep
 * the rules in one readable table instead of a file-sized conditional chain.
 */
const compiledChecks = {
	'dest/lua/autorun/moonpanel.lua': [
		{ not: /hook\.Add\("PostDrawTranslucentRenderables", ""/, message: 'obsolete per-frame matrix experiment is still installed' },
	],
	'dest/lua/moonpanel/canvas/cl_canvas.lua': [
		{ pattern: /\blocal barWidth = self:GetBarWidth\(\)/, message: 'RecalculateClient must scope barWidth locally' },
		{ all: [
			/if data\.powered ~= nil then\s+powered = data\.powered == true/,
			/self:SetPowerState\(powered\)/,
		], message: 'panel state import can discard restored presentation before power replication' },
		{ all: [
			/surface_SetDrawColor\(traceColor\.r, traceColor\.g, traceColor\.b, 255\)/,
			/surface_SetDrawColor\(255, 255, 255, math_Round\(alpha \* 255\)\)/,
		], message: 'trace alpha is not applied at the auxiliary render-target boundary' },
		{ all: [
			/local dataChanged = self\.__dataRevision ~= nil and self\.__dataRevision ~= dataRevision/,
			/Moonpanel\.Net\.TraceSessions\[panel\] = nil/,
		], message: 'panel edits do not invalidate stale client trace sessions by data generation' },
	],
	'dest/lua/moonpanel/cl_net.lua': [
		{ pattern: /local geometryMatches\s+if localHash == result\.finalHash then\s+geometryMatches = true/, message: 'visual-result geometryMatches escaped its local scope' },
		{ pattern: /net\.WriteInt\(sample\.xQ, 16\)\s+net\.WriteInt\(sample\.yQ, 16\)\s+net\.WriteBool\(sample\.boost\)\s+net\.WriteUInt\(sample\.commandNumber or 0, 32\)\s+net\.WriteUInt\(#sample\.constraints, 2\)/, message: 'trace samples do not serialize constraint decisions after movement' },
		{ pattern: /pathfinder:applySample\(sample\.xQ, sample\.yQ, sample\.boost, nil, sample\.constraints\)/, message: 'observers do not replay authoritative constraint decisions' },
		{ pattern: /local snapshot = net\.ReadTable\(\)\s+local orbitSeed = net\.ReadBool\(\) and net\.ReadTable\(\) or nil/, message: 'control grants do not read the pillar orbit seed after the trace snapshot' },
		{ all: [
			/Moonpanel\.Net\.MaintainPanelDataRequests = function/,
			/canvas:ImportNetworkState\(panel, data\)/,
			/request\.nextAttempt = now \+ 1/,
		], message: 'late-join panel state lacks direct apply or bounded retry' },
		{ all: [
			/CreateClientConVar\("moonpanel_server_authoritative_trace", "0"/,
			/serverSequence = lastSequence/,
			/isLocalController and not Moonpanel:IsServerAuthoritativeTrace\(\)/,
			/canvas:ApplyTraceSample\(sample\.xQ, sample\.yQ, sample\.boost, nil, sample\.constraints\)/,
		], message: 'server-authoritative controller mode does not consume the existing server advance stream' },
		{ all: [
			/hash = \(function\(\)[\s\S]*?Moonpanel:IsServerAuthoritativeTrace\(\)[\s\S]*?return 0/,
			/if not \(Moonpanel:IsServerAuthoritativeTrace\(\)\) then/,
			/panel:GetCanvas\(\):End\(false\)/,
			/panel:GetCanvas\(\):End\(true\)/,
		], message: 'server-authoritative mode does not suppress local prediction and terminal gameplay' },
		{ not: /MaintainPanelDataRequests = function[\s\S]*?ents_GetAll\(\)/, message: 'retry maintenance scans every entity instead of pending panels' },
	],
	'dest/lua/moonpanel/cl_init.lua': [
		{ pattern: /timer\.Create\("TheMP Panel State Synchronization", 1, 0/, message: 'late-join panel synchronization maintenance is not installed' },
		{ pattern: /if not \(IsValid\(LocalPlayer\(\)\)\) then\s+self\.Initialized = false/, message: 'client initialization is unsafe before LocalPlayer exists' },
	],
	'dest/lua/moonpanel/sv_net.lua': [
		{ pattern: /Moonpanel\.Net\.PanelRequestDataFromPlayer = function[\s\S]*?PendingPlayerDataRequests\[panel\] = \{[\s\S]*?return Moonpanel\.Net\.SendPanelDataFromPlayerRequest\(ply, panel\)/, message: 'editor payload requests still depend on an unrelated client panel-sync pull' },
	],
	'dest/lua/moonpanel/cl_debug.lua': [
		{ all: [
			/CreateClientConVar\("moonpanel_debug", "0"/,
			/render_DrawLine\(ray\.startPos, ray\.endPos/,
			/hook\.Add\("PostDrawTranslucentRenderables", "Moonpanel Runtime Debug"/,
		], message: 'runtime panel diagnostics or occlusion rays are incomplete' },
		{ not: /RunConsoleCommand\("developer"/, message: 'diagnostics must never mutate the protected developer ConVar' },
		{ pattern: /cam\.PushModelMatrix\(transform\)/, message: 'panel diagnostics must use the panel plane without billboarding' },
		{ not: /cam\.Start3D2D/, message: 'panel diagnostics must use the panel plane without billboarding' },
	],
	'dest/lua/moonpanel/sh_focus.lua': [
		{ all: [
			/Moonpanel\.IsFocused = function\(self, ply\)[\s\S]*?if not \(IsValid\(ply\)\) then[\s\S]*?return false/,
			/Moonpanel:GetPredictedControl\(owner\)/,
		], message: 'focus access or its NW2 proxy is unsafe during LocalPlayer teardown' },
		{ pattern: /PillarController\.ProcessCommand\(ply, cmd, use, originalButtons\)/, message: 'StartCommand does not delegate pillar input to the isolated controller' },
	],
	'dest/lua/moonpanel/sh_control.lua': [
		{ all: [
			/Moonpanel\.GetPredictedControl = function\(self, ply\)[\s\S]*?if not \(IsValid\(ply\)\) then[\s\S]*?return/,
			/Moonpanel:IsFocused\(owner\)/,
		], message: 'control access or its NW2 proxy is unsafe during LocalPlayer teardown' },
	],
	'dest/lua/entities/moonpanel/init.lua': [
		{ pattern: /powered = self:GetPowered\(\),\s+solved = self:GetSolvedState\(\)/, message: 'panel synchronization does not carry authoritative power and solved state together' },
		{ pattern: /self:SetSolvedState\(solved, visualResult\)[\s\S]*?self:ExecutePendingSyncs\(\)/, message: 'restored solved state is not applied before pending clients synchronize' },
		{ pattern: /self:EndTraceSession\(true\)[\s\S]*?canvas:ImportData\(data\)/, message: 'panel edits can import replacement data before evicting the active solver' },
	],
	'dest/lua/weapons/gmod_tool/stools/moonpanel.lua': [
		{ pattern: /sf:SetData\(tileData, solved, visualResult\)/, message: 'duplicator restoration does not atomically import panel and solved state' },
		{ not: /trace\.Entity:RequestDataFromPlayer\(ply\)/, message: 'existing-panel tool clicks issue duplicate editor payload requests' },
	],
	'dest/lua/entities/moonpanel/shared.lua': [
		{ pattern: /ENT\.Monitor_Offsets = Moonpanel\.Canvas\.Monitor_Offsets/, message: 'toolgun model-offset compatibility alias is missing' },
		{ pattern: /if self\.__rendering and self\.__canvas then\s+return self\.__canvas:RenderRT\(\)/, message: 'render-target maintenance is not using the existing entity Think' },
	],
	'dest/lua/entities/moonpanel/cl_init.lua': [
		{ not: /hook\.Add\("Think"/, message: 'panel installs a redundant per-entity global Think hook' },
	],
	'dest/lua/moonpanel/canvas/sh_net.lua': [
		{ pattern: /for k, v in ipairs\(flowTypes\)/, message: 'flow IDs are not derived in stable array order' },
	],
};

function runPillarChecks(source, file, failures) {
	forbidPattern(failures, file, source, /Set(?:Pos|Origin|Velocity)\s*\(/, 'pillar following must not write player transforms or own a movement hook');
	forbidPattern(failures, file, source, /hook\.Add\("(?:Move|SetupMove|FinishMove)"/, 'pillar following must not write player transforms or own a movement hook');
	requireAll(failures, file, source, [
		/util_TraceHull\(\{[\s\S]*?mask = MASK_PLAYERSOLID[\s\S]*?collisiongroup = COLLISION_GROUP_PLAYER_MOVEMENT/,
		/cmd:SetMouseX\(requestedXQ\)\s+cmd:SetMouseY\(requestedYQ\)/,
		/cmd:ClearMovement\(\)/,
	], 'pillar commands lack ghost collision, exact sample encoding, or movement suppression');
	forbidPattern(failures, file, source, /state\.radius = radius/, 'pillar follower is not anchored to its captured orbit');
	requirePattern(failures, file, source, /GetPillarRadialCorrection\([\s\S]*?Controller\.RadiusCorrectionSpeed/, 'pillar follower is not anchored to its captured orbit');
	const cachedCommand = source.match(/Controller\.ApplyCachedCommand = function[\s\S]*?^end$/m);
	if (!cachedCommand ||
		!/Controller\.MakeFollowerMovement\(state, ply, cmd, cached\.maxSpeed or 1, radiusSafe, minimumRadius, cached\.ghostAngle\)/.test(cachedCommand[0]) ||
		/cached\.(?:forwardMove|sideMove|viewAngles)/.test(cachedCommand[0])) {
		addFailure(failures, file, 'replayed pillar commands reuse position-dependent movement');
	}
}

function runCanvasChecks(source, file, failures) {
	const raySites = source.match(/self:_DebugOcclusionRay\(/g) || [];
	if (raySites.length !== 3) addFailure(failures, file, 'expected start, fanout, and refinement occlusion ray sites');
	forbidPattern(failures, file, source, /current == previous/, 'observer RT invalidation must use visible geometry changes, not table identity');
	requirePattern(failures, file, source, /local _, geometryChanged = self\.__observerFollower:update\(FrameTime\(\)/, 'observer RT invalidation must use visible geometry changes, not table identity');
	requirePattern(failures, file, source, /self\.__presentation and \(not self\.__visualFrame or self\.__visualFrame\.needsSampling\)/, 'settled presentations are still sampled every frame');
}

function runPathChecks(source, file, failures) {
	const cleanup = source.match(/CleanUpPathNodes = function\(self[\s\S]*?RenderBelowTrace = function/);
	const renderer = source.match(/RenderBelowTrace = function\(self\)[\s\S]*?surface_DrawRect[\s\S]*?\n    end\n  }\n/);
	if (!cleanup || !renderer || /surface_DrawRect/.test(cleanup[0]) ||
		!/local x, y, w, h = pathBounds\(self\)/.test(renderer[0])) {
		addFailure(failures, file, 'Disjoint cleanup and rendering methods are improperly nested');
	}
}

function runServerNetworkChecks(source, file, failures) {
	const inputBatch = source.match(/receive\(flowTypes\.TraceInputBatch[\s\S]*?receive\(flowTypes\.TraceAction/);
	const fields = inputBatch && [
		'local xQ = net.ReadInt(16)',
		'local yQ = net.ReadInt(16)',
		'local boost = net.ReadBool()',
		'local commandNumber = net.ReadUInt(32)',
		'local constraintCount = net.ReadUInt(2)',
	].map((field) => inputBatch[0].indexOf(field));
	if (!fields || fields.some((position) => position < 0) ||
		fields.some((position, index) => index > 0 && position <= fields[index - 1])) {
		addFailure(failures, file, 'trace samples do not deserialize constraint decisions in writer order');
	}
	requireAll(failures, file, source, [
		/net\.WriteTable\(panel:GetCanvas\(\):GetPathFinder\(\):snapshot\(\)\)\s+local hasOrbitSeed/,
		/Moonpanel\.Net\.PillarProofTimeout = 1\.5/,
		/deadline = CurTime\(\) \+ Moonpanel\.Net\.PillarProofTimeout/,
		/session\.pillarProofs\[sample\.commandNumber\]/,
	], 'pillar orbit seeds or deferred command-proof validation are incomplete');
	requireAll(failures, file, source, [
		/sample = sample or \{ \}\s+proof = proof or \{ \}/,
		/local proof = nil\s+local original = \{\s+xQ = sample\.xQ,\s+yQ = sample\.yQ,\s+commandNumber = sample\.commandNumber/,
	], 'pillar mismatch diagnostics can escape local scope or interrupt the session');
	requireAll(failures, file, source, [
		/net\.Broadcast\(\)/,
		/batch\.predictedHash ~= 0 and serverHash ~= batch\.predictedHash/,
	], 'server-authoritative trace updates are not broadcast or hash-gated correctly');
	const observerAdvance = source.match(/Moonpanel\.Net\.BroadcastObserverAdvance = function[\s\S]*?Moonpanel\.Net\.BroadcastTraceResult = function/);
	if (!observerAdvance || !/net\.WriteUInt\(#sample\.constraints, 2\)/.test(observerAdvance[0]) || /net\.WriteTable/.test(observerAdvance[0])) {
		addFailure(failures, file, 'observer advance must stream constrained samples, not per-batch snapshots');
	}
}

function runCompiledSourceChecks() {
	if (!fs.existsSync(compiledRoot)) throw new Error(`Compiled Lua directory is missing: ${path.relative(projectRoot, compiledRoot)}`);
	const failures = [];
	for (const file of walk(compiledRoot)) {
		const relativeFile = path.relative(projectRoot, file);
		const source = fs.readFileSync(file, 'utf8');
		const checks = compiledChecks[relativeFile] || [];
		for (const check of checks) {
			if (check.all) requireAll(failures, relativeFile, source, check.all, check.message);
			else if (check.not) forbidPattern(failures, relativeFile, source, check.not, check.message);
			else requirePattern(failures, relativeFile, source, check.pattern, check.message);
		}
		if (relativeFile === 'dest/lua/moonpanel/sh_pillar_controller.lua') runPillarChecks(source, relativeFile, failures);
		if (relativeFile === 'dest/lua/moonpanel/canvas/sh_canvas.lua') runCanvasChecks(source, relativeFile, failures);
		if (relativeFile === 'dest/lua/moonpanel/canvas/entities/sh_paths.lua') runPathChecks(source, relativeFile, failures);
		if (relativeFile === 'dest/lua/moonpanel/sv_net.lua') runServerNetworkChecks(source, relativeFile, failures);

		for (const [lineNumber, line] of source.split(/\r?\n/).entries()) {
			for (const match of line.matchAll(/self:__(\w+)\s*\(/g)) {
				const name = `__${match[1]}`;
				if (!allowedPrivateMethodCalls.has(name)) addFailure(failures, `${relativeFile}:${lineNumber + 1}`, line.trim());
			}
			for (const [pattern, message] of precedenceTraps) {
				if (pattern.test(line)) addFailure(failures, `${relativeFile}:${lineNumber + 1}`, `${message}: ${line.trim()}`);
			}
		}
	}
	if (failures.length) throw new Error(`Suspicious compiled Lua:\n  ${failures.join('\n  ')}`);
}

function luaString(value) {
	return `"${value.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, '\\n').replace(/\r/g, '\\r').replace(/\t/g, '\\t')}"`;
}

function toLua(value) {
	if (value === null || value === undefined) return 'nil';
	if (typeof value === 'boolean') return value ? 'true' : 'false';
	if (typeof value === 'number') {
		if (!Number.isFinite(value)) throw new Error('Panel fixtures cannot contain non-finite numbers');
		return String(value);
	}
	if (typeof value === 'string') return luaString(value);
	if (Array.isArray(value)) return `{${value.map(toLua).join(',')}}`;
	if (typeof value === 'object') return `{${Object.keys(value).sort().map((key) => `[${luaString(key)}]=${toLua(value[key])}`).join(',')}}`;
	throw new Error(`Unsupported panel fixture value: ${typeof value}`);
}

function compilePanelFixtures() {
	const manifestNames = fs.readdirSync(panelFixtureRoot).filter((name) => name.endsWith('.fixture.json')).sort();
	const fixtures = manifestNames.map((manifestName) => {
		const manifestPath = path.join(panelFixtureRoot, manifestName);
		const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
		if (!manifest.name || !manifest.panel || !Array.isArray(manifest.tests) || !manifest.tests.length) {
			throw new Error(`${manifestName}: name, panel, and a non-empty tests array are required`);
		}
		for (const [index, testCase] of manifest.tests.entries()) {
			if (!testCase.name || !testCase.expected || !Array.isArray(testCase.traces)) {
				throw new Error(`${manifestName}: tests[${index}] requires name, traces, and expected`);
			}
		}
		const panelPath = path.resolve(panelFixtureRoot, manifest.panel);
		if (path.dirname(panelPath) !== path.resolve(panelFixtureRoot)) throw new Error(`${manifestName}: panel must be beside its fixture manifest`);
		return {
			name: manifest.name,
			source: path.relative(projectRoot, panelPath),
			legacy: manifest.legacy === true,
			topologyRevision: manifest.topologyRevision || 1,
			tests: manifest.tests,
			panel: JSON.parse(fs.readFileSync(panelPath, 'utf8')),
		};
	});
	fs.mkdirSync(path.dirname(generatedPanelFixtures), { recursive: true });
	fs.writeFileSync(generatedPanelFixtures, `-- Generated by tools/sanity.js from tools/fixtures/panels.\nreturn ${toLua(fixtures)}\n`);
	return path.relative(projectRoot, generatedPanelFixtures);
}

const luaTests = [
	['tools/tests/surface.lua'],
	['tools/tests/canvas_runtime.lua'],
	['tools/tests/pillar_controller.lua'],
	['tools/tests/pathfinder.lua'],
	['tools/tests/determinism.lua', '25000', '79225'],
	['tools/tests/determinism.lua', '25000', '19088743'],
	['tools/tests/presentation.lua'],
	['tools/tests/solution.lua'],
	['tools/tests/panel_fixtures.lua'],
	['tools/tests/paneldata.lua'],
	['tools/tests/debug.lua'],
	['tools/tests/editor_document.lua'],
	['tools/tests/editor_store.lua'],
	['tools/tests/panel_sync.lua'],
];

const luaJitTests = luaTests.filter((test) => !(
	test[0] === 'tools/tests/determinism.lua' || test[0] === 'tools/tests/canvas_runtime.lua'
));

function runLuaTest(test, runtime, fixtureModule) {
	const [relativePath, ...args] = test;
	const resolvedArgs = relativePath === 'tools/tests/panel_fixtures.lua' ? [fixtureModule] : args;
	const result = childProcess.spawnSync(runtime, [relativePath, ...resolvedArgs], {
		cwd: projectRoot,
		encoding: 'utf8',
	});
	if (result.stdout) process.stdout.write(`${runtime} ${relativePath}: ${result.stdout}`);
	if (result.status !== 0) {
		if (result.stderr) process.stderr.write(result.stderr);
		throw new Error(`${runtime} test failed: ${relativePath}`);
	}
}

function run() {
	runCompiledSourceChecks();
	let fixtureModule;
	try {
		fixtureModule = compilePanelFixtures();
	} catch (error) {
		throw new Error(`Panel fixture compilation failed: ${error.message}`);
	}
	for (const test of luaTests) runLuaTest(test, 'lua', fixtureModule);
	if (childProcess.spawnSync('luajit', ['-v'], { stdio: 'ignore' }).status === 0) {
		for (const test of luaJitTests) runLuaTest(test, 'luajit', fixtureModule);
	}
}

try {
	run();
} catch (error) {
	console.error(error.message);
	process.exitCode = 1;
}
