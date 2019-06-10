--@include moonpanel/core/moonpanel.txt

tile = require "moonpanel/core/moonpanel.txt"

if SERVER
    width = 20
    height = 20

    cells = {
        {
            x: 1
            y: 1
            type: "Triangle"
            attributes: {
                count: 1
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
            y: height + 1
            type: "Entrance"
        }
        {
            x: 1
            y: 1
            type: "Exit"
        }
        {
            x: width + 1
            y: 1
            type: "Exit"
        }
    }

    vpaths = {
    }
    
    hpaths = {
    }

    for i = 1, width + 1 
        for j = 1, height
            if (math.random 0, 100) > 90
                table.insert vpaths, {
                    x: i
                    y: j
                    type: "Broken"
                }

    for i = 1, width
        for j = 1, height + 1
            if (math.random 0, 100) > 90
                table.insert hpaths, {
                    x: i
                    y: i
                    type: "Broken"
                }

    tile\setup {
        :cells
        :vpaths
        :hpaths
        :intersections
        tile: {
            width: width
            height: height
            symmetry: HORIZONTAL_SYMMETRY
        }
    }