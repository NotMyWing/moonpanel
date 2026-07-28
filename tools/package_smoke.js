const fs = require('fs');
const os = require('os');
const path = require('path');
const childProcess = require('child_process');

const {
	collectFiles,
	createPackage,
	readGma,
	verifyPackage,
} = require('./gma');

const projectRoot = path.join(__dirname, '..');
const compiledRoot = path.join(projectRoot, 'dest');

function parseArgs(argv) {
	const args = {};
	for (let index = 0; index < argv.length; index += 1) {
		if (!argv[index].startsWith('--')) continue;
		args[argv[index].slice(2)] = argv[index + 1] && !argv[index + 1].startsWith('--')
			? argv[++index]
			: true;
	}
	return args;
}

function assert(condition, message) {
	if (!condition) throw new Error(message);
}

function read(relative) {
	return fs.readFileSync(path.join(compiledRoot, relative), 'utf8');
}

function verifyWithOfficialGmad(gmaPath, expectedFiles) {
	const explicit = process.env.MOONPANEL_GMAD || process.env.GMAD;
	const executable = explicit || (process.platform === 'win32' ? 'gmad.exe' : 'gmad');
	const probe = childProcess.spawnSync(executable, [], { stdio: 'ignore' });
	if (probe.error) {
		if (explicit) throw new Error(`Configured gmad executable could not be run: ${explicit}`);
		return false;
	}

	const temporaryRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'moonpanel-gmad-'));
	try {
		childProcess.execFileSync(executable, [
			'extract', '-file', path.resolve(gmaPath), '-out', temporaryRoot,
		], { stdio: 'ignore' });
		const extracted = collectFiles(temporaryRoot, { exclude: [] });
		assert(extracted.length === expectedFiles.length, 'Official gmad extracted a different file count');
		for (let index = 0; index < expectedFiles.length; index += 1) {
			assert(extracted[index].path === expectedFiles[index].path &&
				extracted[index].contents.equals(expectedFiles[index].contents),
				`Official gmad extraction differs at ${expectedFiles[index].path}`);
		}
		return true;
	} finally {
		fs.rmSync(temporaryRoot, { recursive: true, force: true });
	}
}

function run() {
	const args = parseArgs(process.argv.slice(2));
	assert(fs.existsSync(compiledRoot), 'Package smoke test requires a compiled dest directory');
	assert(fs.existsSync(path.join(compiledRoot, 'addon.json')), 'Package source is missing addon.json');
	const files = collectFiles(compiledRoot);
	const paths = new Set(files.map((file) => file.path));
	const required = [
		'lua/autorun/moonpanel.lua',
		'lua/moonpanel/shared.lua',
		'lua/moonpanel/sv_resources.lua',
		'lua/moonpanel/sv_wire.lua',
		'lua/entities/gmod_wire_expression2/core/custom/moonpanel.lua',
		'lua/entities/moonpanel/shared.lua',
		'lua/entities/moonpanel/init.lua',
		'lua/entities/moonpanel/cl_init.lua',
		'materials/moonpanel/common/color.png',
		'sound/moonpanel/presets/default/panel_scint_endpoint.ogg',
	];
	for (const file of required) assert(paths.has(file), `Package is missing required runtime file: ${file}`);
	for (const file of paths) {
		assert(!file.startsWith('test/'), `Generated test data leaked into the addon package: ${file}`);
		assert(!file.endsWith('.moon'), `MoonScript source leaked into the addon package: ${file}`);
	}

	const autorun = read('lua/autorun/moonpanel.lua');
	assert(/AddCSLuaFile/.test(autorun), 'Autorun does not register client Lua files');
	assert(/file\.Find/.test(autorun), 'Autorun does not recursively register Moonpanel Lua files');
	const resources = read('lua/moonpanel/sv_resources.lua');
	assert(/resource\.AddSingleFile/.test(resources), 'Server resource registration is missing');
	assert(/materials\/moonpanel/.test(resources) && /sound\/moonpanel/.test(resources), 'Material or sound resources are not registered');
	const wire = read('lua/moonpanel/sv_wire.lua');
	assert(/CreateInputs/.test(wire) && /TurnOff/.test(wire) && /Reset/.test(wire), 'Wire inputs are missing');
	assert(/SolvedPulse/.test(wire) && /FailedPulse/.test(wire) && /Path/.test(wire), 'Wire outputs are missing');
	const entity = read('lua/entities/moonpanel/init.lua');
	assert(/ResetPanel/.test(entity), 'Wire reset bypasses the panel lifecycle API');
	assert(/WireDupeInfo/.test(entity) && /BuildDupeInfo/.test(entity) && /ApplyDupeInfo/.test(entity), 'Wire duplication metadata hooks are missing');
	assert(/WireLib\.Restored/.test(entity), 'Wire map-restore hook is missing');
	const e2 = read('lua/entities/gmod_wire_expression2/core/custom/moonpanel.lua');
	assert(/RegisterExtension\("moonpanel"/.test(e2) &&
		/moonpanelPowered/.test(e2) && /moonpanelReset/.test(e2),
		'Moonpanel E2 extension is missing its typed API');

	const configuredGma = args.temporary ? null : (args.gma || process.env.MOONPANEL_GMA);
	const configuredManifest = args.temporary ? null : (args.manifest || process.env.MOONPANEL_MANIFEST);
	if (configuredGma || args['require-gma']) {
		const gmaPath = path.resolve(configuredGma || path.join(projectRoot, 'artifacts', 'moonpanel.gma'));
		const manifestPath = path.resolve(configuredManifest || path.join(projectRoot, 'artifacts', 'moonpanel.manifest.json'));
		assert(fs.existsSync(gmaPath), `Package GMA is missing: ${path.relative(projectRoot, gmaPath)}`);
		verifyPackage(compiledRoot, gmaPath, manifestPath);
		const official = verifyWithOfficialGmad(gmaPath, files);
		console.log(`Package smoke passed for ${path.relative(projectRoot, gmaPath)} (${files.length} files${official ? ', official gmad verified' : ''})`);
		return;
	}

	const temporaryRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'moonpanel-package-'));
	const gmaPath = path.join(temporaryRoot, 'moonpanel.gma');
	const manifestPath = path.join(temporaryRoot, 'moonpanel.manifest.json');
	try {
		const created = createPackage(compiledRoot, gmaPath, manifestPath);
		assert(created.files.length === files.length, 'Generated GMA file count differs from package manifest');
		const parsed = readGma(gmaPath);
		assert(parsed.files.length === files.length, 'GMA reader did not recover every packaged file');
		verifyPackage(compiledRoot, gmaPath, manifestPath);
		const official = verifyWithOfficialGmad(gmaPath, files);
		console.log(`Package smoke passed (${files.length} files, ${fs.statSync(gmaPath).size} bytes${official ? ', official gmad verified' : ''})`);
	} finally {
		fs.rmSync(temporaryRoot, { recursive: true, force: true });
	}
}

try {
	run();
} catch (error) {
	console.error(error.message);
	process.exitCode = 1;
}
