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
        {
            x: 1
            y: 2
            type: "Triangle"
            attributes: {
                count: 2
            }
        }
        {
            x: 2
            y: 1
            type: "Triangle"
            attributes: {
                count: 3
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
            x: 2
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
        {
            x: 3
            y: 3
            type: "Exit"
        }
        {
            x: 1
            y: 3
            type: "Exit"
        }
        {
            x: 2
            y: 1
            type: "Exit"
        }
    }

    tile\setup {
        :cells
        :vpaths
        :intersections
    }