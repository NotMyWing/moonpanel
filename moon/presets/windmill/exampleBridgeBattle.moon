--@include moonpanel/core/moonpanel.txt

tile = require "moonpanel/core/moonpanel.txt"

if SERVER
    width = 5
    height = 3 
    cells = {
        {
            x: 3
            y: 2
            type: "Triangle"
            attributes: {
                count: 3
            }
        }
        {
            x: 1
            y: 3
            type: "Sun"
            attributes: {
                color: COLOR_ORANGE
            }
        }
        {
            x: 1
            y: 1
            type: "Sun"
            attributes: {
                color: COLOR_ORANGE
            }
        }
        {
            x: 5
            y: 1
            type: "Sun"
            attributes: {
                color: COLOR_ORANGE
            }
        }
        {
            x: 5
            y: 3
            type: "Sun"
            attributes: {
                color: COLOR_ORANGE
            }
        }
        {
            x: 2
            y: 2
            type: "Color"
            attributes: {
                color: COLOR_BLACK
            }
        }
        {
            x: 4
            y: 2
            type: "Color"
            attributes: {
                color: COLOR_WHITE
            }
        }
    }

    intersections = {
        {
            x: 1
            y: 4
            type: "Entrance"
        }
        {
            x: 6
            y: 1
            type: "Exit"
        }
    }

    vpaths = {
        {
            x: 3
            y: 1
            type: "Broken"
        }
        {
            x: 5
            y: 2
            type: "Broken"
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