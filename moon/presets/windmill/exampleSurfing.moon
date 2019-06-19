--@include moonpanel/core/moonpanel.txt

tile = require "moonpanel/core/moonpanel.txt"

if SERVER
    width = 4
    height = 4
    cells = {
        {
            x: 1
            y: 1
            type: "Sun"
            attributes: {
                color: COLOR_YELLOW
            }
        }
        {
            x: 1
            y: 2
            type: "Sun"
            attributes: {
                color: COLOR_YELLOW
            }
        }
        {
            x: 1
            y: 3
            type: "Sun"
            attributes: {
                color: COLOR_YELLOW
            }
        }
        {
            x: 1
            y: 4
            type: "Sun"
            attributes: {
                color: COLOR_YELLOW
            }
        }
        {
            x: 2
            y: 1
            type: "Sun"
            attributes: {
                color: COLOR_BLUE
            }
        }
        {
            x: 2
            y: 2
            type: "Sun"
            attributes: {
                color: COLOR_BLUE
            }
        }
        {
            x: 2
            y: 3
            type: "Sun"
            attributes: {
                color: COLOR_CYAN
            }
        }
        {
            x: 2
            y: 4
            type: "Sun"
            attributes: {
                color: COLOR_CYAN
            }
        }
        {
            x: 3
            y: 1
            type: "Sun"
            attributes: {
                color: COLOR_BLUE
            }
        }
        {
            x: 3
            y: 2
            type: "Sun"
            attributes: {
                color: COLOR_BLUE
            }
        }
        {
            x: 3
            y: 3
            type: "Sun"
            attributes: {
                color: COLOR_CYAN
            }
        }
        {
            x: 3
            y: 4
            type: "Sun"
            attributes: {
                color: COLOR_CYAN
            }
        }
        {
            x: 4
            y: 1
            type: "Sun"
            attributes: {
                color: COLOR_WHITE
            }
        }
        {
            x: 4
            y: 2
            type: "Sun"
            attributes: {
                color: COLOR_WHITE
            }
        }
        {
            x: 4
            y: 3
            type: "Sun"
            attributes: {
                color: COLOR_WHITE
            }
        }
        {
            x: 4
            y: 4
            type: "Sun"
            attributes: {
                color: COLOR_WHITE
            }
        }
    }

    intersections = {
        {
            x: 3
            y: 5
            type: "Entrance"
        }
        {
            x: 3
            y: 1
            type: "Exit"
        }
    }

    vpaths = {
        {
            x: 2
            y: 2
            type: "Hexagon"
        }
        {
            x: 4
            y: 2
            type: "Hexagon"
        }
    }

    hpaths = {
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