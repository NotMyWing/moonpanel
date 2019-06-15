--@include moonpanel/core/moonpanel.txt

tile = require "moonpanel/core/moonpanel.txt"

if SERVER
    width = 4
    height = 4

    cells = {
        {
            x: 3
            y: 1
            type: "Color"
            attributes: {
                color: COLOR_GREEN
            }
        }
        {
            x: 1
            y: 4
            type: "Color"
            attributes: {
                color: COLOR_GREEN
            }
        }
        {
            x: 2
            y: 3
            type: "Color"
            attributes: {
                color: COLOR_RED
            }
        }
        {
            x: 4
            y: 3
            type: "Triangle"
            attributes: {
                count: 2
            }
        }
        {
            x: 2
            y: 4
            type: "Triangle"
            attributes: {
                count: 1
            }
        }
        {
            x: 3
            y: 2
            type: "Sun"
            attributes: {
                color: COLOR_WHITE
            }
        }
        {
            x: 1
            y: 3
            type: "Sun"
            attributes: {
                color: COLOR_WHITE
            }
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

    tile\setup {
        :cells,
        :intersections
        :vpaths
        :hpaths
        tile: {
            width: width
            height: height
        }
        colors: {
        }
    }