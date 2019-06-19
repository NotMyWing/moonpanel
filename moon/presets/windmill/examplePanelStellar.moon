--@include moonpanel/core/moonpanel.txt

tile = require "moonpanel/core/moonpanel.txt"

if SERVER
    width = 4
    height = 4

    cells = {
        {
            x: 2
            y: 2
            type: "Sun"
            attributes: {
                color: COLOR_YELLOW
            }
        }
        {
            x: 3
            y: 2
            type: "Sun"
            attributes: {
                color: COLOR_YELLOW
            }
        }
        {
            x: 2
            y: 3
            type: "Sun"
            attributes: {
                color: COLOR_YELLOW
            }
        }
        {
            x: 3
            y: 3
            type: "Sun"
            attributes: {
                color: COLOR_YELLOW
            }
        }
        {
            x: 4
            y: 2
            type: "Y"
        }
    }

    intersections = {
        {
            x: 1
            y: 5
            type: "Entrance"
        }
        {
            x: 5
            y: 1
            type: "Exit"
        }
        {
            x: 1
            y: 4
            type: "Hexagon"
        }
        {
            x: 1
            y: 3
            type: "Hexagon"
        }
        {
            x: 2
            y: 3
            type: "Hexagon"
        }
        {
            x: 3
            y: 3
            type: "Hexagon"
        }
        {
            x: 3
            y: 2
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
    }

    vpaths = {
        {
            x: 1
            y: 4
            type: "Hexagon"
        }
        {
            x: 1
            y: 3
            type: "Hexagon"
        }
        {
            x: 3
            y: 1
            type: "Hexagon"
        }
        {
            x: 3
            y: 2
            type: "Hexagon"
        }
    }

    hpaths = {
        {
            x: 1
            y: 3
            type: "Hexagon"
        }
        {
            x: 2
            y: 3
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
            x: 3
            y: 3
            type: "Broken"
        }
    }

    tile\setup {
        :cells,
        :intersections
        :hpaths
        :vpaths
        tile: {
            width: width
            height: height
        }
    }