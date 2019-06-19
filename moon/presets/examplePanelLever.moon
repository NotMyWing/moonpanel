--@include moonpanel/core/moonpanel.txt

tile = require "moonpanel/core/moonpanel.txt"

if SERVER
    intersections = {
        {
            x: 1
            y: 1
            type: "Exit"
        }
        {
            x: 2
            y: 1
            type: "Entrance"
        }
        {
            x: 3
            y: 1
            type: "Exit"
        }
    }

    tile\setup {
        :intersections
        tile: {
            width: 2
            height: 0
            innerScreenRatio: 0.8
            barWidth: 80
        }
    }