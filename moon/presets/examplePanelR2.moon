--@include moonpanel/core/moonpanel.txt

tile = require "moonpanel/core/moonpanel.txt"

if SERVER
    width = 4
    height = 4

    cells = {
        {
            x: 1
            y: 2
            type: "Color"
            attributes: {
                color: COLOR_WHITE
            }
        }
        {
            x: 3
            y: 1
            type: "Color"
            attributes: {
                color: COLOR_BLACK 
            }
        }
        {
            x: 2
            y: 3
            type: "Color"
            attributes: {
                color: COLOR_BLACK
            }
        }
        {
            x: 1
            y: 1
            type: "Triangle"
            attributes: {
                count: 2
            }
        }
        {
            x: 3
            y: 2
            type: "Triangle"
            attributes: {
                count: 1
            }
        }
        {
            x: 1
            y: 4
            type: "Triangle"
            attributes: {
                count: 2
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
            x: 4
            y: 4 
            type: "Y"
        }
    }

    intersections = {
        {
            x: 1
            y: 2
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
        colors: {
        }
    }