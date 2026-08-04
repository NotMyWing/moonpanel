const { Transform } = require('stream');
const luaFormat = require('lua-format');
const { streamToBuffer } = require('./util');

const FORMAT_OPTIONS = {
	RenameVariables: false,
	RenameGlobals: false,
	// SolveMath folds GLua expressions unsafely (notably geometry bounds).
	SolveMath: false,
	Indentation: '',
};

const LUA_FORMAT_BANNER = /^--\[\[\n\tCode generated using github\.com\/Herrtt\/luamin\.js\n\tAn open source Lua beautifier and minifier\.\n--\]\]\n*/;

function stripLuaFormatBanner(code) {
	return code.replace(LUA_FORMAT_BANNER, '');
}

function formatLua(code) {
	return stripLuaFormatBanner(luaFormat.Beautify(code, FORMAT_OPTIONS));
}

/**
 * Formats Lua files using lua-format's Luamin-compatible parser while
 * retaining structural newlines for readable compiled output.
 */
class LuaFormatTransform extends Transform {

	constructor() {
		super({ objectMode: true });
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
			streamToBuffer(file.contents, (err, contents) => {
				if (err) this.emit('error', err);
				else {
					const code = contents.toString(encoding);
					const formattedCode = formatLua(code);
					file.contents = Buffer.from(formattedCode, encoding);
					next(null, file);
				}
			});
		}

		if (file.isBuffer()) {
			const code = file.contents.toString(encoding);
			const formattedCode = formatLua(code);
			file.contents = Buffer.from(formattedCode, encoding);
			next(null, file);
		}

	}
}

module.exports = () => new LuaFormatTransform();
module.exports.LuaFormatTransform = LuaFormatTransform;
