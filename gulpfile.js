const { src, watch, dest, series } = require('gulp');
const { spawn } = require('child_process');
const through2 = require('through2');
const luamin = require('luamin');
const del = require('del');
const gulp = require('gulp');

const _compileMoonScript = () => through2.obj((file, _, cb) => {
	if (file.isBuffer()) {
		const moonc = spawn('moonc', ['--']);

		let stdout = '';
		let stderr = '';

		const code = file.contents.toString();
		const lines = code.split(/\r?\n/);
		let header = '';
		for (const line of lines) {
			if (line != '' && !line.startsWith('--')) break;
			header += line + '\n';
		}

		moonc.stdin.write(code);
		moonc.stdin.end();

		moonc.stdout.on('data', data => { stdout += data; });
		moonc.stderr.on('data', data => { stderr += data; });
		moonc.on('close', () => {
			if (stderr) cb(stderr);
			else {
				file.path = file.path.substr(0, file.path.lastIndexOf('.')) + '.lua';
				// file.contents = Buffer.from(header + luamin.minify(stdout));
				file.contents = Buffer.from(header + stdout);
				cb(null, file);
			}
		});
	}
});

const _moveLuaFiles = () => through2.obj((file, _, cb) => {
	if (file.isBuffer()) {
		const code = file.contents.toString();
		const lines = code.split(/\r?\n/);
		let header = '';
		for (const line of lines) {
			if (line != '' && !line.startsWith('--')) break;
			header += line + '\n';
		}

		file.contents = Buffer.from(header + luamin.minify(file.contents.toString()));
		file.path = file.path.substr(0, file.path.lastIndexOf('.')) + '.lua';
		cb(null, file);
	}
});

function rmrf(cb) {
	del(['lua/**/*']).then(() => {
		cb();
	});
}

function lua() {
	return src('moon/**/*.lua')
		.pipe(_moveLuaFiles())
		.pipe(dest('lua'));
}

function moon() {
	return src('moon/**/*.moon')
		.pipe(_compileMoonScript())
		.pipe(dest('lua'));
}

function _watch() {
	return watch(['moon/**/*.lua', 'moon/**/*.moon'], gulp.series(lua, moon));
}

exports.moon = moon;
exports.watch = _watch;
exports.default = _watch;