--@include moonpanel/core/moonpanel.txt

tile = require "moonpanel/core/moonpanel.txt"

if SERVER
    width = 4
    height = 4

    cells = {
        {
            x: 1
            y: 1
            type: "Triangle"
            attributes: {
                count: 1
            }
        }
        {
            x: 1
            y: 2
            type: "Triangle"
            attributes: {
                count: 1
            }
        }
        {
            x: 1
            y: 3
            type: "Triangle"
            attributes: {
                count: 1
            }
        }
        {
            x: 1
            y: 4
            type: "Triangle"
            attributes: {
                count: 1
            }
        }
        {
            x: 4
            y: 1
            type: "Triangle"
            attributes: {
                count: 1
            }
        }
        {
            x: 4
            y: 2
            type: "Triangle"
            attributes: {
                count: 1
            }
        }
        {
            x: 4
            y: 3
            type: "Triangle"
            attributes: {
                count: 1
            }
        }
        {
            x: 4
            y: 4
            type: "Triangle"
            attributes: {
                count: 1
            }
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
    }

    vpaths = {
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