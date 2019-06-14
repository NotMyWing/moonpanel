--@include moonpanel/core/moonpanel.txt

tile = require "moonpanel/core/moonpanel.txt"

if SERVER
    width = 3
    height = 3

    cells = {

        {
            x: 2
            y: 2
            type: "Triangle"
            attributes: {
                count: 3
            }
        }

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
        tile: {
            :width
            :height
        }
        :cells
        :vpaths
        :intersections
    }