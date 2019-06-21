# StarfallEX-Moonpanel
It's a panel, written in moon language. As inspired by The Witness, a game by Thekla Inc.

Important notice: this panel DOES NOT support negative polyominoes. All other elements, including polyominoes, Y-symbols, coloured squares, suns and triangles, are supported. You can also import [The Windmill puzzles](https://windmill.thefifthmatt.com) if you want to! Currently this requires a bit of preparation though.

![hi](https://media.discordapp.net/attachments/403032923508310017/591472190914822154/unknown.png?width=1087&height=678)

# How do I X?

Obviously, the first thing you'll need is [StarfallEx](https://github.com/thegrb93/StarfallEx). I haven't tested it with vanilla Starfall, but if you do, let me know if it works.

If you want to just screw around, navigate to Releases section and steal the latest release. Unzip the archive somewhere, navigate to your garry's mod folder, search for the `/garrysmod/data/starfall` directory and plop the `moonpanel` folder there.

If you want some presets, there is a bunch of them in the `moonpanelPresets` folder. Drop it into the starfall directory as well and spawn a chip.

# How do I X: Advanced stuff

To get started, install Node.js, and run `npm install` in this directory. Either via cmd, or bash, or you using a shell of your choice.

To download a puzzle from The Windmill, type `node windmillDownloader.js`.

If you want to contribute, run `gulp moon` to compile the code, and just `gulp` to watch.
