--@include moonpanel/core/moonpanel.txt

tile = require "moonpanel/core/moonpanel.txt"

if SERVER
    width = 1
    height = 1

    cells = {
    }

    intersections = {
        
    }

    vpaths = {
    }
    
    hpaths = {
        {
            x: 1
            y: 1
            type: "Entrance"
        }
        {
            x: 1
            y: 2
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