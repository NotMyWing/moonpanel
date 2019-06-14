--@include moonpanel/core/moonpanel.txt

tile = require "moonpanel/core/moonpanel.txt"

if SERVER
    cells = {
    }

    vpaths = {
    }

    intersections = {
        {
            x: 1
            y: 3
            type: "Entrance"
        }
        {
            x: 3
            y: 3
            type: "Entrance"
        }
        {
            x: 1
            y: 1
            type: "Exit"
        }
        {
            x: 3
            y: 1
            type: "Exit"
        }
    }

    tile\setup {
        :intersections
        :cells
        tile: {
            width: 2
            height: 2
        }
    }