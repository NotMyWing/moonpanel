--@include moonpanel/core/moonpanel.txt

tile = require "moonpanel/core/moonpanel.txt"

if SERVER
    width = 3
    height = 3

    cells = {
        {
            x: 1
            y: 1
            type: "Color"
            attributes: {
                color: COLOR_RED
            }
        }
        {
            x: 3
            y: 1
            type: "Color"
            attributes: {
                color: COLOR_BLUE
            }
        }
        {
            x: 1
            y: 3
            type: "Color"
            attributes: {
                color: COLOR_CYAN
            }
        }
        {
            x: 3
            y: 3
            type: "Color"
            attributes: {
                color: COLOR_WHITE
            }
        }
        {
            x: 2
            y: 2
            type: "Y"
        }
    }

    intersections = {
        {
            x: 1
            y: height + 1
            type: "Entrance"
        }
        {
            x: width + 1
            y: 1
            type: "Exit"
        }
    }

    vpaths = {
    }
    
    hpaths = {
    }

    tile\setup {
        :cells
        :vpaths
        :hpaths
        :intersections
        tile: {
            width: width
            height: height
        }
    }