--@include moonpanel/core/moonpanel.txt

tile = require "moonpanel/core/moonpanel.txt"

if SERVER
    width = 3
    height = 3

    cells = {
    }

    intersections = {
        
    }

    vpaths = {
    }
    
    hpaths = {
        {
            x: 2
            y: 4
            type: "Entrance"
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
        :hpaths
        :intersections
        tile: {
            width: width
            height: height
        }
    }