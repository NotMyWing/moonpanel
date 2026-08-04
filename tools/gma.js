const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const MAGIC = Buffer.from('GMAD', 'ascii');
const FORMAT_VERSION = 3;
const MAX_FILE_NAME_BYTES = 180;

const ALLOWED_EXTENSIONS = new Set([
	'.lua', '.json', '.png', '.jpg', '.jpeg', '.gif', '.vtf', '.vmt',
	'.wav', '.ogg', '.mp3', '.mp4', '.mdl', '.vvd', '.dx90.vtx', '.vtx',
	'.phy', '.ani', '.pcf', '.ttf', '.otf', '.properties', '.res', '.txt',
]);

const FORBIDDEN_EXTENSIONS = new Set([
	'.dll', '.exe', '.htm', '.html', '.css', '.js', '.moon', '.md', '.zip',
]);

let crcTable;
function getCrcTable() {
	if (crcTable) return crcTable;
	crcTable = new Uint32Array(256);
	for (let i = 0; i < 256; i += 1) {
		let value = i;
		for (let bit = 0; bit < 8; bit += 1) {
			value = (value & 1) ? (value >>> 1) ^ 0xedb88320 : value >>> 1;
		}
		crcTable[i] = value >>> 0;
	}
	return crcTable;
}

function crc32(buffer) {
	let value = 0xffffffff;
	const table = getCrcTable();
	for (const byte of buffer) {
		value = (value >>> 8) ^ table[(value ^ byte) & 0xff];
	}
	return (value ^ 0xffffffff) >>> 0;
}

function writeUInt64(value) {
	const buffer = Buffer.alloc(8);
	buffer.writeBigUInt64LE(BigInt(value));
	return buffer;
}

function writeCString(value) {
	const buffer = Buffer.from(String(value), 'utf8');
	if (buffer.includes(0)) throw new Error('GMA strings cannot contain NUL bytes');
	return Buffer.concat([buffer, Buffer.from([0])]);
}

function readCString(buffer, state) {
	const end = buffer.indexOf(0, state.offset);
	if (end < 0) throw new Error('Malformed GMA: unterminated string');
	const value = buffer.subarray(state.offset, end).toString('utf8');
	state.offset = end + 1;
	return value;
}

function normalizeRelativeFile(file) {
	const normalized = file.split(path.sep).join('/').replace(/^\.\//, '');
	if (!normalized || normalized.startsWith('/') || normalized.includes('../') || normalized === '..') {
		throw new Error(`Invalid addon path: ${file}`);
	}
	if (normalized !== normalized.toLowerCase()) {
		throw new Error(`Addon paths must be lowercase: ${normalized}`);
	}
	const lower = normalized.toLowerCase();
	const extension = lower.endsWith('.dx90.vtx') ? '.dx90.vtx' : path.posix.extname(lower);
	if (FORBIDDEN_EXTENSIONS.has(extension) || !ALLOWED_EXTENSIONS.has(extension)) {
		throw new Error(`File type is not allowed in a GMA: ${normalized}`);
	}
	if (lower.endsWith('.txt') &&
		!lower.startsWith('scripts/vehicles/') &&
		!lower.startsWith('data_static/')) {
		throw new Error(`Only vehicle scripts and static data text files are allowed in a GMA: ${normalized}`);
	}
	if (Buffer.byteLength(normalized, 'utf8') > MAX_FILE_NAME_BYTES) {
		throw new Error(`Addon path exceeds ${MAX_FILE_NAME_BYTES} bytes: ${normalized}`);
	}
	return normalized;
}

function collectFiles(root, options = {}) {
	const rootPath = path.resolve(root);
	const excluded = new Set((options.exclude || ['test', 'archive.zip', 'addon.json'])
		.map((value) => value.replace(/\\/g, '/').toLowerCase()));
	const files = [];
	const seen = new Map();

	function visit(directory) {
		for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
			const absolute = path.join(directory, entry.name);
			const relative = path.relative(rootPath, absolute).split(path.sep).join('/');
			const relativeKey = relative.toLowerCase();
			if (excluded.has(relativeKey) || [...excluded].some((prefix) => relativeKey.startsWith(`${prefix}/`))) continue;
			if (entry.isDirectory()) {
				visit(absolute);
				continue;
			}
			if (!entry.isFile()) continue;
			const archivePath = normalizeRelativeFile(relative.toLowerCase());
			if (seen.has(archivePath)) {
				throw new Error(`Case-insensitive duplicate addon path: ${seen.get(archivePath)} and ${relative}`);
			}
			seen.set(archivePath, relative);
			const contents = fs.readFileSync(absolute);
			if (contents.length === 0) throw new Error(`GMA files cannot be empty: ${relative}`);
			files.push({ path: archivePath, source: absolute, contents });
		}
	}

	visit(rootPath);
	files.sort((a, b) => a.path < b.path ? -1 : a.path > b.path ? 1 : 0);
	if (files.length === 0) throw new Error(`No addon files found in ${root}`);
	return files;
}

function addonMetadata(root) {
	const metadataPath = path.join(root, 'addon.json');
	if (!fs.existsSync(metadataPath)) throw new Error('Package is missing addon.json');
	const metadata = JSON.parse(fs.readFileSync(metadataPath, 'utf8'));
	return {
		name: typeof metadata.title === 'string' && metadata.title.trim() ? metadata.title.trim() : 'The Moonpanel',
		description: typeof metadata.description === 'string' ? metadata.description : '',
	};
}

function makeManifest(files) {
	return files.map((file) => ({
		path: file.path,
		size: file.contents.length,
		sha256: crypto.createHash('sha256').update(file.contents).digest('hex'),
	}));
}

function buildGma(root, options = {}) {
	const files = collectFiles(root, options);
	const metadata = addonMetadata(root);
	const timestamp = options.timestamp === undefined ? 0 : Number(options.timestamp);
	const parts = [
		MAGIC,
		Buffer.from([FORMAT_VERSION]),
		writeUInt64(0),
		writeUInt64(timestamp),
		Buffer.from([0]),
		writeCString(metadata.name),
		writeCString(metadata.description),
		writeCString('The Moonpanel contributors'),
		Buffer.from([1, 0, 0, 0]),
	];

	files.forEach((file, index) => {
		const number = Buffer.alloc(4);
		number.writeUInt32LE(index + 1);
		const size = writeUInt64(file.contents.length);
		const crc = Buffer.alloc(4);
		crc.writeUInt32LE(crc32(file.contents));
		parts.push(number, writeCString(file.path), size, crc);
	});
	const terminator = Buffer.alloc(4);
	parts.push(terminator);
	for (const file of files) parts.push(file.contents);
	const body = Buffer.concat(parts);
	const archiveCrc = Buffer.alloc(4);
	archiveCrc.writeUInt32LE(crc32(body));
	return { buffer: Buffer.concat([body, archiveCrc]), files, manifest: makeManifest(files) };
}

function readGma(input) {
	const buffer = Buffer.isBuffer(input) ? input : fs.readFileSync(input);
	const state = { offset: 0 };
	if (!buffer.subarray(0, 4).equals(MAGIC)) throw new Error('Malformed GMA: invalid magic');
	state.offset = 4;
	const version = buffer[state.offset++];
	if (version !== FORMAT_VERSION) throw new Error(`Unsupported GMA version: ${version}`);
	if (buffer.length < 32) throw new Error('Malformed GMA: truncated header');
	const steamId = buffer.readBigUInt64LE(state.offset); state.offset += 8;
	const timestamp = buffer.readBigUInt64LE(state.offset); state.offset += 8;
	if (buffer[state.offset++] !== 0) throw new Error('Malformed GMA: required-content list is unsupported');
	const name = readCString(buffer, state);
	const description = readCString(buffer, state);
	const author = readCString(buffer, state);
	if (state.offset + 4 > buffer.length) throw new Error('Malformed GMA: missing addon version');
	const addonVersion = buffer.readInt32LE(state.offset); state.offset += 4;
	const records = [];
	while (true) {
		if (state.offset + 4 > buffer.length) throw new Error('Malformed GMA: missing file terminator');
		const number = buffer.readUInt32LE(state.offset); state.offset += 4;
		if (number === 0) break;
		const filePath = readCString(buffer, state);
		if (state.offset + 12 > buffer.length) throw new Error(`Malformed GMA record: ${filePath}`);
		const size = Number(buffer.readBigUInt64LE(state.offset)); state.offset += 8;
		const crc = buffer.readUInt32LE(state.offset); state.offset += 4;
		records.push({ number, path: filePath, size, crc });
	}
	const payloadStart = state.offset;
	const payloadSize = records.reduce((total, record) => total + record.size, 0);
	const payloadEnd = payloadStart + payloadSize;
	if (payloadEnd + 4 !== buffer.length) throw new Error('Malformed GMA: payload length mismatch');
	if (crc32(buffer.subarray(0, payloadEnd)) !== buffer.readUInt32LE(payloadEnd)) {
		throw new Error('Malformed GMA: archive CRC mismatch');
	}
	const files = [];
	for (const record of records) {
		const contents = buffer.subarray(state.offset, state.offset + record.size);
		state.offset += record.size;
		if (crc32(contents) !== record.crc) throw new Error(`GMA file CRC mismatch: ${record.path}`);
		files.push({ path: record.path, contents, size: record.size, crc: record.crc });
	}
	return { version, steamId, timestamp, name, description, author, addonVersion, files };
}

function writeAtomic(filePath, contents) {
	fs.mkdirSync(path.dirname(filePath), { recursive: true });
	const temporary = `${filePath}.tmp-${process.pid}`;
	fs.writeFileSync(temporary, contents);
	fs.renameSync(temporary, filePath);
}

function createPackage(input, output, manifestOutput, options = {}) {
	const result = buildGma(input, options);
	writeAtomic(output, result.buffer);
	if (manifestOutput) writeAtomic(manifestOutput, `${JSON.stringify(result.manifest, null, 2)}\n`);
	return result;
}

function verifyPackage(input, gmaPath, manifestPath, options = {}) {
	const expected = buildGma(input, options);
	const actual = readGma(gmaPath);
	if (actual.files.length !== expected.files.length) throw new Error('GMA file count differs from the package source');
	for (let i = 0; i < expected.files.length; i += 1) {
		const wanted = expected.files[i];
		const found = actual.files[i];
		if (wanted.path !== found.path || !wanted.contents.equals(found.contents)) {
			throw new Error(`GMA contents differ at ${wanted.path}`);
		}
	}
	if (manifestPath && fs.existsSync(manifestPath)) {
		const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
		if (JSON.stringify(manifest) !== JSON.stringify(expected.manifest)) {
			throw new Error('Package manifest differs from the source package');
		}
	}
	return { files: actual.files, manifest: expected.manifest };
}

function parseArgs(argv) {
	const args = {};
	for (let i = 0; i < argv.length; i += 1) {
		if (!argv[i].startsWith('--')) continue;
		args[argv[i].slice(2)] = argv[i + 1] && !argv[i + 1].startsWith('--') ? argv[++i] : true;
	}
	return args;
}

if (require.main === module) {
	try {
		const command = process.argv[2];
		const args = parseArgs(process.argv.slice(3));
		if (command === 'create') {
			const result = createPackage(args.input || 'dest', args.output || 'artifacts/moonpanel.gma', args.manifest || 'artifacts/moonpanel.manifest.json');
			console.log(`Created ${args.output || 'artifacts/moonpanel.gma'} (${result.files.length} files)`);
		} else if (command === 'verify') {
			const result = verifyPackage(args.input || 'dest', args.gma || 'artifacts/moonpanel.gma', args.manifest || 'artifacts/moonpanel.manifest.json');
			console.log(`Verified ${result.files.length} packaged files`);
		} else {
			throw new Error('Usage: node tools/gma.js <create|verify> [--input dir] [--output file] [--gma file] [--manifest file]');
		}
	} catch (error) {
		console.error(error.message);
		process.exitCode = 1;
	}
}

module.exports = {
	buildGma,
	collectFiles,
	createPackage,
	readGma,
	verifyPackage,
};
