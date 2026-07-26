const gulp = require('gulp');
const del = require('del');
const fs = require('fs');
const path = require('path');
const through = require('through2');
const gulpZip = require('gulp-zip');

const minifyLua = require('./tools/luamin');
const compileMoonscript = require('./tools/moonscript');
const optimizeLua = require ('./tools/optimizations');
const discourageLuaMod = require ('./tools/discourageLuaModification');

const MATERIAL_GLOBS = [
	'src/materials/**/*',
	'!src/materials/**/*.svg',
];

const SOUND_GLOBS = [
	'src/sound/**/*',
];

const MODEL_GLOBS = [
	'src/models/**/*',
];

const METADATA_GLOBS = [
	'src/addon.json',
];

const E2_EXTENSION_GLOBS = [
	'src/lua/entities/gmod_wire_expression2/core/custom/**/*.lua',
];

let atomicWriteId = 0;

/**
 * Write each Vinyl file through a same-directory temporary file and rename it
 * into place. The rename is atomic on the target filesystem, so live-reload
 * consumers never observe a truncated output file.
 */
function atomicDest(directory) {
	const root = path.resolve(directory);

	return through.obj(function(file, encoding, callback) {
		if(file.isNull()) {
			callback(null, file);
			return;
		}

		if(!file.isBuffer()) {
			callback(new Error('Cannot atomically write streamed file: ' + file.path));
			return;
		}

		const target = path.join(root, file.relative);
		const temporary = target + '.tmp-' + process.pid + '-' + atomicWriteId++;

		try {
			fs.mkdirSync(path.dirname(target), { recursive: true });
			fs.writeFileSync(temporary, file.contents, {
				mode: file.stat && file.stat.mode,
			});
			fs.renameSync(temporary, target);
			callback(null, file);
		} catch(error) {
			try {
				fs.unlinkSync(temporary);
			} catch(_) {
				// Preserve the original write error.
			}
			callback(error);
		}
	});
}

/**
 * Cleans the build.
 */
function clean() {
	return del(['dest/**/*']);
}
clean.description = "Cleans the build.";


/**
 * Minifies lua files.
 */
function lua() {
	return gulp.src([
		'src/**/*.lua',
		'!src/lua/entities/gmod_wire_expression2/core/custom/**/*.lua',
	], { since: gulp.lastRun(lua) })
		.pipe(optimizeLua())
		.pipe(minifyLua())
		.pipe(atomicDest('dest'));
}
lua.description = "Copies and minifies lua files.";

/**
 * Copies WireMod E2 extension sources without transforming them.
 */
function e2Extensions() {
	return gulp.src(E2_EXTENSION_GLOBS, { base: 'src', since: gulp.lastRun(e2Extensions) })
		.pipe(atomicDest('dest'));
}
e2Extensions.description = "Copies WireMod E2 extensions without transforming them.";


/**
 * Compiles moonscript files.
 */
function moon() {
	return gulp.src('src/**/*.moon', { since: gulp.lastRun(moon) })
		.pipe(compileMoonscript())
		.pipe(optimizeLua())
		.pipe(discourageLuaMod())
		// .pipe(minifyLua())
		.pipe(atomicDest('dest'));
}
moon.description = "Compiles moonscript files.";


/**
 * Builds the addon scripts.
 */
const scripts = gulp.parallel(lua, moon, e2Extensions);
scripts.description = "Builds the addon scripts.";


/**
 * Watches lua files and compiles changes.
 */
function watchScripts() {
	return gulp.watch(
		['src/**/*.lua', 'src/**/*.moon']
		, scripts
	)
}
watchScripts.displayName = "watch-scripts";
watchScripts.description = "Watches lua and moon files and compiles changes.";


/**
 * Copies materials.
 */
function materials() {
	return gulp.src(MATERIAL_GLOBS, { since: gulp.lastRun(materials) })
		.pipe(atomicDest('dest/materials'));
}
materials.description = "Copies materials.";

/**
 * Copies sound files.
 */
function sound() {
	return gulp.src(SOUND_GLOBS, { since: gulp.lastRun(sound) })
		.pipe(atomicDest('dest/sound'));
}
sound.description = "Copies sound files.";

/**
 * Copies model files.
 */
function model() {
	return gulp.src(MODEL_GLOBS, { since: gulp.lastRun(model) })
		.pipe(atomicDest('dest/models'));
}
model.description = "Copies model files.";

/**
 * Copies metadata files.
 */
function metadata() {
	return gulp.src(METADATA_GLOBS, { since: gulp.lastRun(metadata) })
		.pipe(atomicDest('dest'));
}
metadata.description = "Copies metadata files.";

/**
 * Packages the compiled addon as a loose-file zip. The archive contains the
 * addon root rather than a `dest/` wrapper and excludes generated tests and
 * stale archives retained by the live-refresh build.
 */
function packageZip() {
	return gulp.src([
		'dest/**/*',
		'!dest/test/**',
		'!dest/**/*.zip',
	], { base: 'dest', allowEmpty: false })
		.pipe(gulpZip('moonpanel.zip'))
		.pipe(atomicDest('artifacts'));
}
packageZip.description = "Packages the compiled addon as a zip.";

/**
 * Generates and moves assets.
 */
const assets = gulp.parallel(materials, sound, model, metadata);
assets.description = "Generates and copies assets.";

/**
 * Watches asset files and compiles/copies changes.
 */
function watchAssets() {
	return gulp.watch(
		[
			...MATERIAL_GLOBS,
			...SOUND_GLOBS,
			...MODEL_GLOBS,
			...METADATA_GLOBS,
		]
		, assets
	)
}
watchAssets.displayName = "watch-assets";
watchAssets.description = "Watches assets.";

/**
 * Builds everything.
 */
const build = gulp.parallel(scripts, assets);
build.description = "Builds everything.";

/**
 * Builds the project without deleting the live output tree, and then watches
 * files for changes. This is intentionally safe for Garry's Mod live refresh.
 */
const watch = gulp.series(build, gulp.parallel(watchAssets, watchScripts));
watch.description = "Builds in place and watches files for changes.";

/**
 * Explicit destructive reset for recovering from stale or orphaned output.
 */
const rebuild = gulp.series(clean, build);
rebuild.description = "Deletes the output tree, then performs a clean build.";


exports.clean = clean;
exports.materials = materials;
exports.assets = assets;
exports.watchAssets = watchAssets;
exports.packageZip = packageZip;
exports.lua = lua;
exports.moon = moon;
exports.scripts = scripts;
exports.watchScripts = watchScripts;
exports.build = build;
exports.rebuild = rebuild;
exports.watch = watch;
exports.default = watch;
