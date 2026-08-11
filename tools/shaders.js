'use strict';

const childProcess = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const projectRoot = path.resolve(__dirname, '..');
const compiler = process.env.MOONPANEL_SHADER_COMPILER;
const sources = [
	['moonpanel_display_v3_vs20.hlsl', 'moonpanel_display_v3_vs20.vcs'],
	['moonpanel_display_v3_ps2x.hlsl', 'moonpanel_display_v3_ps20b.vcs'],
];

if (!compiler) {
	throw new Error('Set MOONPANEL_SHADER_COMPILER to a standalone Source ShaderCompile executable.');
}

const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'moonpanel-shaders-'));
const sourceRoot = path.join(projectRoot, 'shadersrc');
const outputRoot = path.join(projectRoot, 'src', 'shaders', 'fxc');

function validateVCS(file) {
	const data = fs.readFileSync(file);
	if (data.length < 48 || data.readUInt32LE(0) !== 6) {
		throw new Error(`Unsupported or truncated VCS output: ${file}`);
	}

	const dictionaryEntries = data.readUInt32LE(20);
	const dictionaryEnd = 28 + dictionaryEntries * 8;
	if (dictionaryEntries < 2 || dictionaryEnd + 4 > data.length) {
		throw new Error(`Invalid VCS combo dictionary: ${file}`);
	}

	const sentinel = dictionaryEnd - 8;
	if (data.readUInt32LE(sentinel) !== 0xffffffff ||
		data.readUInt32LE(sentinel + 4) !== data.length) {
		throw new Error(`Invalid VCS end sentinel: ${file}`);
	}

	const firstBlock = data.readUInt32LE(32);
	const blockSize = data.readUInt32LE(firstBlock);
	const compression = blockSize & 0xc0000000;
	const payloadSize = blockSize & 0x3fffffff;
	if (firstBlock + 4 + payloadSize + 4 > data.length ||
		data.readUInt32LE(firstBlock + 4 + payloadSize) !== 0xffffffff) {
		throw new Error(`Invalid VCS shader block: ${file}`);
	}
	if (compression === 0x40000000 && data.toString('ascii', firstBlock + 4,
		firstBlock + 8) !== 'LZMA') {
		throw new Error(`Invalid VCS LZMA payload: ${file}`);
	}
}

function replaceAtomically(source, destination) {
	const temporaryOutput = `${destination}.tmp-${process.pid}`;
	fs.copyFileSync(source, temporaryOutput);
	validateVCS(temporaryOutput);
	fs.renameSync(temporaryOutput, destination);
}

try {
	for (const name of ['common.hlsl', ...sources.map(([name]) => name)]) {
		fs.copyFileSync(path.join(sourceRoot, name), path.join(temporary, name));
	}

	for (const [source] of sources) {
		const command = process.platform === 'win32' || !compiler.toLowerCase().endsWith('.exe')
			? compiler
			: (process.env.MOONPANEL_WINE || 'wine');
		const args = command === compiler
			? ['/O', '3', '-ver', '20b', '-shaderpath', temporary, source]
			: [compiler, '/O', '3', '-ver', '20b', '-shaderpath', temporary, source];
		const result = childProcess.spawnSync(command, args, { stdio: 'inherit' });
		if (result.error) throw result.error;
		if (result.status !== 0) throw new Error(`Shader compilation failed for ${source}.`);
	}

	fs.mkdirSync(outputRoot, { recursive: true });
	for (const [, output] of sources) {
		replaceAtomically(path.join(temporary, 'shaders', 'fxc', output),
			path.join(outputRoot, output));
	}
} finally {
	fs.rmSync(temporary, { recursive: true, force: true });
}

console.log(`Compiled ${sources.length} Moonpanel shaders.`);
