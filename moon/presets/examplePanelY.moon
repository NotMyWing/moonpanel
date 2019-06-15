--@include moonpanel/core/moonpanel.txt

tile = require "moonpanel/core/moonpanel.txt"

if SERVER
    width = 4
    height = 4

    cells = {
        {
            x: 1
            y: 1
            type: "Color"
            attributes: {
                color: 1
            }
        }
        {
            x: 2
            y: 1
            type: "Color"
            attributes: {
                color: 2
            }
        }
        {
            x: 3
            y: 1
            type: "Color"
            attributes: {
                color: 3
            }
        }
        {
            x: 4
            y: 1
            type: "Color"
            attributes: {
                color: 4
            }
        }
        {
            x: 1
            y: 4 
            type: "Y"
        }
        {
            x: 2
            y: 4 
            type: "Y"
        }
        {
            x: 3
            y: 4 
            type: "Y"
        }
    }

    intersections = {
        {
            x: 1
            y: 5
            type: "Entrance"
        }
        {
            x: 5
            y: 1
            type: "Exit"
        }
    }

    tile\setup {
        :cells,
        :intersections
        tile: {
            width: width
            height: height
        }
    }