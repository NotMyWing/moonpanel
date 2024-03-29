const gulp = require('gulp');
const del = require('del');

const minifyLua = require('./tools/luamin');
const compileMoonscript = require('./tools/moonscript');
const optimizeLua = require ('./tools/optimizations');
const discourageLuaMod = require ('./tools/discourageLuaModification');

const lastRunCache = new Map();
function lastRunIgnoreErrors(task) {
	const lastRun = gulp.lastRun(task);
	if(lastRun) {
		lastRunCache.set(task, lastRun);
		return lastRun;
	}
	else {
		return lastRunCache.get(task);
	}
}

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
	return gulp.src('src/**/*.lua', { since: lastRunIgnoreErrors(lua) })
		.pipe(optimizeLua())
		.pipe(minifyLua())
		.pipe(gulp.dest('dest', { mode: 0777 }));
}
lua.description = "Copies and minifies lua files.";


/**
 * Compiles moonscript files.
 */
function moon() {
	return gulp.src('src/**/*.moon', { since: lastRunIgnoreErrors(moon) })
		.pipe(compileMoonscript())
		.pipe(optimizeLua())
		.pipe(discourageLuaMod())
		// .pipe(minifyLua())
		.pipe(gulp.dest('dest', { mode: 0777 }));
}
moon.description = "Compiles moonscript files.";


/**
 * Builds the addon scripts.
 */
const scripts = gulp.parallel(lua, moon);
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
	return gulp.src(MATERIAL_GLOBS, { since: lastRunIgnoreErrors(materials) })
		.pipe(gulp.dest('dest/materials/', { mode: 0777 }));
}
materials.description = "Copies materials.";

/**
 * Copies sound files.
 */
function sound() {
	return gulp.src(SOUND_GLOBS, { since: lastRunIgnoreErrors(materials) })
		.pipe(gulp.dest('dest/sound/', { mode: 0777 }));
}
materials.description = "Copies sound files.";

/**
 * Copies model files.
 */
function model() {
	return gulp.src(MODEL_GLOBS, { since: lastRunIgnoreErrors(materials) })
		.pipe(gulp.dest('dest/models/', { mode: 0777 }));
}
materials.description = "Copies model files.";

/**
 * Copies metadata files.
 */
function metadata() {
	return gulp.src(METADATA_GLOBS, { since: lastRunIgnoreErrors(materials) })
		.pipe(gulp.dest('dest', { mode: 0777 }));
}
materials.description = "Copies metadata files.";

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
 * Cleans and builds the project, and then watches files for changes.
 */
const watch = gulp.series(clean, build, gulp.parallel(watchAssets, watchScripts));
watch.description = "Cleans and builds the project, and then watches files for changes.";


exports.clean = clean;
exports.materials = materials;
exports.assets = assets;
exports.watchAssets = watchAssets;
exports.lua = lua;
exports.moon = moon;
exports.scripts = scripts;
exports.watchScripts = watchScripts;
exports.build = build;
exports.watch = watch;
exports.default = watch;
