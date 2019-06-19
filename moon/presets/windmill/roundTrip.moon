--@include moonpanel/core/moonpanel.txt

tile = require "moonpanel/core/moonpanel.txt"

if SERVER
    width = 5
    height = 6

    cells = { 
         {
            x: 3
            y: 1
            type: "Triangle"
            attributes: {
                count: 3
            }
        }
        {
            x: 3
            y: 2
            type: "Triangle"
            attributes: {
                count: 2
            }
        }
        {
            x: 3
            y: 3
            type: "Triangle"
            attributes: {
                count: 2
            }
        }
        {
            x: 3
            y: 4
            type: "Triangle"
            attributes: {
                count: 2
            }
        }
        {
            x: 3
            y: 5
            type: "Triangle"
            attributes: {
                count: 2
            }
        }
        {
            x: 3
            y: 6
            type: "Triangle"
            attributes: {
                count: 2
            }
        }    
        {
            x: 1
            y: 6
            type: "Sun"
            attributes: {
                color: COLOR_MAGENTA
            }
        }
        {
            x: 5
            y: 6
            type: "Sun"
            attributes: {
                color: COLOR_MAGENTA
            }
        }
    }

    intersections = {
        {
            x: 3
            y: 7
            type: "Entrance"
        }
        {
            x: 4
            y: 7
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