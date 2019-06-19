--@include moonpanel/core/moonpanel.txt

tile = require "moonpanel/core/moonpanel.txt"

if SERVER
    width = 2
    height = 2

    cells = {
        {
            x: 1
            y: 1
            type: "Polyomino"
            attributes: {
                shape: {
                    {1}
                }
                rotational: false
            }
        }
        {
            x: 2
            y: 1
            type: "Polyomino"
            attributes: {
                shape: {
                    {1,1}
                    {0,1}
                }
                rotational: true
            }
        }
        {
            x: 1
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