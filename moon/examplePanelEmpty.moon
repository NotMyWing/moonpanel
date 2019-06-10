--@include moonpanel/core/moonpanel.txt

tile = require "moonpanel/core/moonpanel.txt"

if SERVER
    cells = {
    }

    for i = 1, 2
        for j = 1, 2
            table.insert cells, {
                x: i
                y: j
                type: "Triangle"
                attributes: {
                    count: math.ceil math.random 1, 3
                }
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