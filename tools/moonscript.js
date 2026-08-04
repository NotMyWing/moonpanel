const { spawn, spawnSync } = require('child_process');
const { Transform } = require('stream');

const { streamToBuffer } = require('./util');

/**
 * Compiles moonscript files to lua using the system `moonc` executable.
 */
class MoonscriptTransform extends Transform {

	constructor(compilerPath = "moonc") {
		super({ objectMode: true });
		this.compilerPath = compilerPath;
		this.stdinArgument = this.detectStdinArgument();
	}

	detectStdinArgument() {
		const probe = spawnSync(this.compilerPath, ['--version'], {
			encoding: 'utf8',
			windowsHide: true,
		});
		const version = `${probe.stdout || ''}\n${probe.stderr || ''}`;
		const match = version.match(/(\d+)\.(\d+)(?:\.\d+)?/);
		return match && Number(match[1]) === 0 && Number(match[2]) <= 5 ? '--' : '-';
	}

	/**
	 * Transforms a file.
	 * @param {Object} file The file to process.
	 * @param {string} encoding The encoding of the file.
	 * @param {Function} next A callback function.
	 */
	_transform(file, encoding, next) {
		if (file.isNull()) {
			return next(null, file);
		}

		if (file.isStream()) {
			const moonc = this.spawnMoonc();
			file.contents.pipe(moonc.stdin);
			file.extname = ".lua";
			file.contents = moonc.stdout;
			return next(null, file);
		}

		if (file.isBuffer()) {
			const moonc = this.spawnMoonc();
			moonc.stdin.write(file.contents);
			moonc.stdin.end();

			return streamToBuffer(moonc.stdout, (err, contents) => {
				if (err) return this.emit('error', err);
				file.extname = ".lua";
				file.contents = contents;
				next(null, file);
			});
		}

		next(new Error('MoonScript compiler received an unsupported file stream'));
	}

	spawnMoonc() {
		const moonc = spawn(this.compilerPath, [this.stdinArgument], { windowsHide: true });
		moonc.on('error', this.emit.bind(this, 'error'));

		streamToBuffer(moonc.stderr, (err, content) => {
			if (err) this.emit('error', err);
			if (content.length > 0) this.emit('error', new Error(content.toString()));
		});

		return moonc;
	}
}

module.exports = () => new MoonscriptTransform();
module.exports.MoonscriptTransform = MoonscriptTransform;
