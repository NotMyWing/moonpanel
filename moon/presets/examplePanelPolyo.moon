--@include moonpanel/core/moonpanel.txt

tile = require "moonpanel/core/moonpanel.txt"

if SERVER
    cells = {
        {
            x: 1
            y: 1
            type: "Polyomino"
            attributes: {
                shape: {
                    {1, 1}
                    {0, 0}
                    {1, 0}
                }
                rotational: true
            }
        }
        {
            x: 2
            y: 2
            type: "Polyomino"
            attributes: {
                shape: {
                    {1}
                }
            }
        }
    }

    vpaths = {
    }

    intersections = {
        {
            x: 1
            y: 4
            type: "Entrance"
        }
        {
            x: 4
            y: 1
            type: "Exit"
        }
    }

    tile\setup {
        :intersections
        :cells
        tile: {
            width: 3
            height: 3
        }
    }