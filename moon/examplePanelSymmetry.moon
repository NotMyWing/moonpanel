--@include moonpanel/core/moonpanel.txt

tile = require "moonpanel/core/moonpanel.txt"

if SERVER
    cells = {
        {
            x: 1
            y: 1
            type: "Triangle"
            attributes: {
                count: 1
            }
        }
    }

    vpaths = {
        {
            x: 2
            y: 1
            type: "Broken"
        }
    }

    intersections = {
        {
            x: 1
            y: 7
            type: "Entrance"
        }
        {
            x: 7
            y: 7
            type: "Entrance"
        }
        {
            x: 1
            y: 1
            type: "Exit"
        }
        {
            x: 7
            y: 1
            type: "Exit"
        }
    }

    tile\setup {
        :cells
        :vpaths
        :intersections
        tile: {
            width: 6
            height: 6
            symmetry: HORIZONTAL_SYMMETRY
        }
    }