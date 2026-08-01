# The Moonpanel

Puzzle panels, written in moon language. As inspired by The Witness, a game by Thekla Inc.
Initially written for Starfall/StarfallEx, now a separate addon.

If you don't understand the puzzle mechanics, then perhaps you should play The Witness.

## Getting Started

TBA.

## Build and package

Install Node.js, npm, LuaJIT, and LuaRocks. Install MoonScript through
LuaRocks, then install the project dependencies and run the test suite:

```sh
luarocks install moonscript
npm ci
npm test
```

`npm test` compiles the addon into `dest/`, runs the Lua and LuaJIT tests,
and checks a temporary GMA package.

Create the distributable files with:

```sh
npm run package:gma
npm run package:zip
npm run verify:package
```

The GMA, ZIP, and manifest are written to `artifacts/`. The GMA writer is
implemented in Node and does not require Garry's Mod or `gmad`. To also check
the archive with an installed official `gmad`, set `MOONPANEL_GMAD` when
running `npm run verify:package`.

For live development, use `npm run watch`. It updates files in place using
atomic writes. If generated output is stale, `npm run rebuild` removes and
recreates `dest/` before building.

## Built With

* [Node.js](https://nodejs.org/)
* [LuaJIT](https://luajit.org/)
* [LuaRocks](https://luarocks.org/)
* [Moonscript](https://moonscript.org)

## Contributing

TBA.

## Authors

* **NotMyWing** - [NotMyWing](https://github.com/NotMyWing)

## License

Moonpanel's code is Apache 2.0. See [`LICENSE`](LICENSE).

Some code and assets came from elsewhere. [`NOTICE`](NOTICE) and
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) say what came from where.
The Witness assets still belong to Thekla.

## Acknowledgments

* **Thekla, Inc. and Jonathan Blow** - *The Witness, its puzzle language, original visual and audio assets, and the primary inspiration for this project.*
* [TheFifthMatt](https://windmill.thefifthmatt.com/) - *The existence of The Windmill inspired this project and its later dedicated importer.*
* [Tyler Schrock](https://github.com/Tschrock) - *The Windmill importer.*
* [thegrb93 and contributors](https://github.com/thegrb93/StarfallEx/) - *StarfallEX and the panel rendering codebase*
* [WireMod contributors](https://github.com/wiremod/wire) - *Editor-presence animation*
* [BytewaveMLP](https://github.com/BytewaveMLP) - *Buildscript*

## WireMod and Expression 2

See the [WireMod and Expression 2 guide](docs/WIREMOD.md) for inputs, outputs,
E2 helpers, and duplication behavior.
