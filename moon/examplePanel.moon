--@include moonpanel/core/moonpanel.txt

Tile = require "moonpanel/core/moonpanel.txt"

vpaths = {
    {
        x: 1
        y: 1
        type: "Invisible"
    }
}

Tile {
    elements {
        :cells
        :vpaths
    }
}