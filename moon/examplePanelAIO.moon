--@include moonpanel/core/moonpanel.txt

tile = require "moonpanel/core/moonpanel.txt"

if SERVER
    width = 3
    height = 3

    cells = {
        {
            x: 1
            y: 1
            type: "Color"
            attributes: {
                color: COLOR_RED
            }
        }
        {
            x: 3
            y: 1
            type: "Color"
            attributes: {
                color: COLOR_BLUE
            }
        }
        {
            x: 1
            y: 3
            type: "Color"
            attributes: {
                color: COLOR_CYAN
            }
        }
        {
            x: 3
            y: 1
            type: "Polyomino"
            attributes: {
                shape: {
                    {1,1,1}
                    {1,1,1}
                    {1,1,1}
                }
                fixed: false
            }
        }
        {
            x: 3
            y: 2
            type: "Blue Polyomino"
            attributes: {
                shape: {
                    {1}
                }
                fixed: false
            }
        }
        {
            x: 3
            y: 2
            type: "Blue Polyomino"
            attributes: {
                shape: {
                    {1}
                }
                fixed: false
            }
        }
        {
            x: 3
            y: 3
            type: "Blue Polyomino"
            attributes: {
                shape: {
                    {1}
                }
                fixed: false
            }
        }
        {
            x: 2
            y: 3
            type: "Triangle"
            attributes: {
                count: 3
            }
        }
        {
            x: 2
            y: 1 
            type: "Y"
        }
        {
            x: 2
            y: 2
            type: "Sun"
            attributes: {
                color: COLOR_YELLOW
            }
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

    vpaths = {
        {
            x: 2
            y: 3
            type: "Hexagon"
        }
        {
            x: 2
            y: 1
            type: "Hexagon"
        }
        {
            x: 2
            y: 1
            type: "Hexagon"
        }
    }
    
    hpaths = {
        {
            x: 1
            y: 4
            type: "Hexagon"
        }
        {
            x: 1
            y: 2
            type: "Hexagon"
        }
        {
            x: 1
            y: 3
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