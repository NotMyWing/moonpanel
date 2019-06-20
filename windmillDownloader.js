protobuf = require("protobufjs");
var https = require('https'),
    Stream = require('stream').Transform,
    fs = require('fs'),
    sanitize = require("sanitize-filename"),
    prompts = require('prompts'),
    path = require('path');

var url = 'https://windmill.thefifthmatt.com/_/thing/';

TYPES = {
    3: "Entrance",
    4: "Exit",
    5: "Disjoint",
    6: "Hexagon",
    7: "Color",
    8: "Sun",
    9: "Polyomino",
    10: "Y",
    11: "Triangle"
}

Storage = protobuf.loadSync("grid.proto").lookupTypeOrEnum("Storage");

var input = process.argv[2]

if (!input || input === "") {
    var fname = path.basename(process.argv[1]);
    console.log('\x1b[37m\x1b[1m%s\x1b[0m', 'Usage: node ' + fname + ' link');
    console.log('');
    console.log('Example: node ' + fname + ' https://windmill.thefifthmatt.com/knh0n60');
    console.log('');
    console.log('To download a puzzle from the editor, first click Checkpoint, then copy the link from the address bar.');
    return;
}

new Promise((resolve, reject) => {
    if (input.startsWith("https://windmill.thefifthmatt.com/build/")) {
        var substring = "/build/";
        console.log('\x1b[37m\x1b[1m%s\x1b[0m', '> Parsing editor data...');
        resolve({
            contents: input.substr(input.lastIndexOf(substring) + substring.length, input.length)
        })
    } else {
        input = input.substr(input.lastIndexOf("/") ? input.lastIndexOf("/") + 1 : 0, input.length)
        console.log('\x1b[37m\x1b[1m%s\x1b[0m', '> Fetching ' + input + '...');
        https.request(url + input, function (response) {
            var data = new Stream();

            response.on('data', function (chunk) {
                data.push(chunk);
            });

            response.on('end', function () {
                resolve(JSON.parse(data.read()));
            })
        }).end();
    }
}).then((data) => {
    var headers = {}
    headers.title = data.title;
    headers.id = data.id;
    headers.creator = data.creatorName ? data.creatorName : (data.creator ? data.creator : "someone")
    headers.title = data.title ? data.title : "unnamed"

    contents = data.contents.substring(0, data.contents.length - 2).replace(/_/g, '/').replace(/-/g, '+');

    if (!contents) {
        throw new Error("failed to parse contents");
    }

    var storage = Storage.decode(new Buffer(contents, 'base64'));

    console.log('\x1b[37m\x1b[1m%s\x1b[0m', '> Expanding entities...');

    var width = null;
    var height = null;
    if (!storage.entity || !storage.width) {
        throw new Error("failed to expand entities");
    } else {
        var expandedEntities = [];
        storage.entity.forEach(function (e) {
            for (var i = 0; i < (e.count || 1); i++) {
                expandedEntities.push(e);
            }
        });
        storage.entity = expandedEntities;
        if (storage.entity.length % storage.width != 0) {
            throw Error();
        }
        var storeHeight = Math.floor(storage.entity.length / storage.width);
        width = Math.floor(storage.width / 2);
        height = Math.floor(storeHeight / 2);
    }
    var storeWidth = width * 2 + 1;
    storeHeight = height * 2 + 1;

    toIndex = (a, b) => {
        return a + storeWidth * b;
    }

    console.log('\x1b[37m\x1b[1m%s\x1b[0m', '> Grid data OK. Transpiling...');

    code = "--@include moonpanel/core/moonpanel.txt\n"
    code += "--\n"
    code += "-- AUTOMATICALLY DOWNLOADED & TRANSPILED BY MOONPANEL DOWNLOADER\n"
    if (headers.id) {
        code += "--\n"
        code += "-- \"" + headers.title + "\"\n"
        code += "-- by " + headers.creator + "\n"
        code += "--\n"
        code += "-- https://windmill.thefifthmatt.com/" + headers.id + "\n"
    }
    code += "--\n\n"

    code += "tile = require \"moonpanel/core/moonpanel.txt\"\n\n"

    code += "if SERVER then\n"
    code += "\tcells = {\n";
    for (var i = 0; i < width; i++)
        for (var j = 0; j < height; j++) {
            cell = expandedEntities[toIndex(i * 2 + 1, j * 2 + 1)];
            if (cell.type && cell.type >= 3) {
                code += "\t\t{\n\t\t\ttype = \"" + TYPES[cell.type] + "\",\n"
                code += "\t\t\tx = " + (i + 1) + ",\n"
                code += "\t\t\ty = " + (j + 1) + ",\n"
                if (cell.triangleCount || cell.color || cell.shape) {
                    code += "\t\t\tattributes = {\n"
                    if (cell.triangleCount) {
                        code += "\t\t\t\tcount = " + cell.triangleCount + ",\n"
                    }
                    if (cell.color) {
                        code += "\t\t\t\tcolor = " + cell.color + ",\n"
                    }
                    if (cell.shape) {
                        if (cell.shape.free) {
                            code += "\t\t\t\trotational = true,\n"
                        }
                        code += "\t\t\t\tshape = {\n"
                        shapeW = cell.shape.width
                        shapeH = cell.shape.grid.length / shapeW
                        for (var _j = 0; _j < shapeH; _j++) {
                            code += "\t\t\t\t\t{"
                            for (var _i = 0; _i < shapeW; _i++) {
                                if (_i != 0) {
                                    code += ", "
                                }
                                code += cell.shape.grid[_i + shapeW * _j] ? 1 : 0
                            }
                            code += "},\n"
                        }
                        code += "\t\t\t\t}\n"
                    }
                    code += "\t\t\t}\n"
                }
                code += "\t\t},\n"
            }
        }
    code += "\t}\n"

    code += "\n\tintersections = {\n";
    for (var i = 0; i <= width; i++)
        for (var j = 0; j <= height; j++) {
            int = expandedEntities[toIndex(i * 2, j * 2)]
            if (int && int.type >= 3) {
                code += "\t\t{\n\t\t\ttype = \"" + TYPES[int.type] + "\",\n"
                code += "\t\t\tx = " + (i + 1) + ",\n"
                code += "\t\t\ty = " + (j + 1) + ",\n"
                code += "\t\t},\n"
            }
        }
    code += "\t}\n"

    code += "\n\tvpaths = {\n";
    for (var i = 0; i <= width; i++)
        for (var j = 0; j < height; j++) {
            goDown = 1;
            line = expandedEntities[toIndex(i * 2 + (1 - goDown), j * 2 + goDown)]

            if (line && line.type >= 3) {
                code += "\t\t{\n\t\t\ttype = \"" + TYPES[line.type] + "\",\n"
                code += "\t\t\tx = " + (i + 1) + ",\n"
                code += "\t\t\ty = " + (j + 1) + ",\n"
                code += "\t\t},\n"
            }
        }
    code += "\t}\n"

    code += "\n\thpaths = {\n";
    for (var i = 0; i < width; i++)
        for (var j = 0; j <= height; j++) {
            goDown = 0;
            line = expandedEntities[toIndex(i * 2 + (1 - goDown), j * 2 + goDown)]

            if (line && line.type >= 3) {
                code += "\t\t{\n\t\t\ttype = \"" + TYPES[line.type] + "\",\n"
                code += "\t\t\tx = " + (i + 1) + ",\n"
                code += "\t\t\ty = " + (j + 1) + ",\n"
                code += "\t\t},\n"
            }
        }
    code += "\t}\n"

    code += "\n\ttile:setup({\n"
    code += "\t\tcells = cells,\n"
    code += "\t\tvpaths = vpaths,\n"
    code += "\t\thpaths = hpaths,\n"
    code += "\t\tintersections = intersections,\n"
    code += "\t\ttile = {\n"
    code += "\t\t\twidth = " + width + ",\n"
    code += "\t\t\theight = " + height + "\n"
    code += "\t\t}\n"
    code += "\t})\n"
    code += "end"

    return { headers: headers, code: code };
}).catch((error) => {
    console.log("\n\x1b[31m> Failed to download " + input + ".\n\n" + error + "\x1b[0m");
}).then((data) => {
    var initial = null;
    if (data.headers.id) {
        initial = data.headers.title + " by " + data.headers.creator;
    }

    console.log();
    response = prompts({
        type: 'text',
        name: 'value',
        message: 'Please enter the filename:',
        initial: initial
    }).then((response) => {
        if (!response || !response.value) {
            throw new Error("invalid filename")
        }

        if (!fs.existsSync("./downloaded/")) {
            fs.mkdirSync("./downloaded/");
        }
        var filename = "./downloaded/" + sanitize(response.value) + ".txt";
        code = "--@name " + response.value + "\n" + code;
        fs.writeFileSync(filename, code);
        console.log('\x1b[37m\x1b[1m%s\x1b[0m', '> Saved to ' + filename);

        return true;
    }).catch((error) => {
        console.log("\n\x1b[31m> Couldn't save the file.\n\n" + error + "\x1b[0m");
    })
})

