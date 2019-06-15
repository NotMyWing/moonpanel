--@include moonpanel/core/moonpanel.txt

tile = require "moonpanel/core/moonpanel.txt"

if SERVER
    width = 4
    height = 4

    cells = {
        {
            x: 1
            y: 4 
            type: "Y"
        }
    }

    intersections = {
        {
            x: 3
            y: 3
            type: "Entrance"
        }
        {
            x: 1
            y: 1
            type: "Exit"
        }
        {
            x: 1
            y: 3
            type: "Hexagon"
        }
        {
            x: 1
            y: 4
            type: "Hexagon"
        }
        {
            x: 1
            y: 5
            type: "Hexagon"
        }
        {
            x: 2
            y: 5
            type: "Hexagon"
        }
        {
            x: 3
            y: 5
            type: "Hexagon"
        }
        {
            x: 2
            y: 1
            type: "Hexagon"
        }
        {
            x: 3
            y: 1
            type: "Hexagon"
        }
        {
            x: 4
            y: 1
            type: "Hexagon"
        }
        {
            x: 5
            y: 1
            type: "Hexagon"
        }
        {
            x: 5
            y: 2
            type: "Hexagon"
        }
        {
            x: 5
            y: 3
            type: "Hexagon"
        }
        {
            x: 5
            y: 4
            type: "Hexagon"
        }
        {
            x: 5
            y: 5
            type: "Hexagon"
        }
        {
            x: 4
            y: 5
            type: "Hexagon"
        }
    }

    vpaths = {
        {
            x: 1
            y: 3
            type: "Hexagon"
        }
        {
            x: 1
            y: 4
            type: "Hexagon"
        }
        {
            x: 5
            y: 1
            type: "Hexagon"
        }
        {
            x: 5
            y: 2
            type: "Hexagon"
        }
        {
            x: 5
            y: 3
            type: "Hexagon"
        }
        {
            x: 5
            y: 4
            type: "Hexagon"
        }
    }
    
    hpaths = {
        {
            x: 1
            y: 5
            type: "Hexagon"
        }
        {
            x: 2
            y: 5
            type: "Hexagon"
        }
        {
            x: 3
            y: 5
            type: "Hexagon"
        }
        {
            x: 2
            y: 1
            type: "Hexagon"
        }
        {
            x: 3
            y: 1
            type: "Hexagon"
        }
        {
            x: 4
            y: 1
            type: "Hexagon"
        }
        {
            x: 4
            y: 5
            type: "Hexagon"
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