# The Moonpanel

A Garry's Mod addon for Witness-style puzzle panels. It is written in
MoonScript and compiled to Lua.

The project started as a Starfall/StarfallEx experiment and grew into its own
addon. The Witness is the obvious inspiration. [You should play The Witness](https://store.steampowered.com/app/210970/The_Witness/).

## Development

Install Node.js, LuaJIT, LuaRocks, and MoonScript. Then install the Node
dependencies and run the tests:

```sh
luarocks install moonscript
npm ci
npm test
```

`npm test` rebuilds `dest/`, runs the Lua and LuaJIT suites, and smoke-tests a
temporary GMA package.

Create the distributable files with:

```sh
npm run package:gma
npm run package:zip
npm run verify:package
```

The GMA, ZIP, and manifest go in `artifacts/`. The GMA writer is implemented
in Node, so it does not need Garry's Mod or `gmad`. If `gmad` is installed,
set `MOONPANEL_GMAD` when running `npm run verify:package` to check the archive
with it too.

For live development, use `npm run watch`. It rebuilds generated files in
place. If `dest/` gets stale, run `npm run rebuild`.

## Tools

* [Node.js](https://nodejs.org/)
* [LuaJIT](https://luajit.org/)
* [LuaRocks](https://luarocks.org/)
* [Moonscript](https://moonscript.org)

## People

* **NotMyWing** - [NotMyWing](https://github.com/NotMyWing)

## Code and assets

Moonpanel's code is Apache 2.0; see [`LICENSE`](LICENSE).

Some code and assets came from other projects. See
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) for the list. The Witness
assets belong to Thekla and are not relicensed here.

## Credits

* **Thekla, Inc. and Jonathan Blow** — The Witness and the puzzle language that
  started this whole thing.
* [TheFifthMatt](https://windmill.thefifthmatt.com/) — The Windmill.
* [Tyler Schrock](https://github.com/Tschrock) — The Windmill importer.
* [thegrb93 and contributors](https://github.com/thegrb93/StarfallEx/) — The
  StarfallEx panel code this grew out of.
* [WireMod contributors](https://github.com/wiremod/wire) — The editor-presence
  animation we adapted.
* [BytewaveMLP](https://github.com/BytewaveMLP) — Buildscript work.

## WireMod and Expression 2

See the [WireMod and Expression 2 guide](docs/WIREMOD.md) for inputs, outputs,
E2 helpers, and duplication behavior.
