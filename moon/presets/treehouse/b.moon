--@include moonpanel/core/moonpanel.txt

tile = require "moonpanel/core/moonpanel.txt"

if SERVER
    width = 4
    height = 4

    cells = {
        {
            x: 4
            y: 2
            type: "Sun"
            attributes: {
                color: COLOR_ORANGE
            }
        }
        {
            x: 1
            y: 4
            type: "Sun"
            attributes: {
                color: COLOR_ORANGE
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

    hpaths = {
        {
            x: 3
            y: 1
            type: "Broken"
        }
        {
            x: 2
            y: 2
            type: "Broken"
        }
        {
            x: 4
            y: 2
            type: "Broken"
        }
        {
            x: 2
            y: 4
            type: "Broken"
        }
        {
            x: 2
            y: 5
            type: "Broken"
        }
    }
    vpaths = {
            {
                x: 1
                y: 1
                type: "Broken"
            }
            {
                x: 5
                y: 3
                type: "Broken"
            }
    }

    tile\setup {
        tile: {
            :width
            :height
            innerScreenRatio: 0.85
            barWidth: 45
        }
        colors: {
            background: Color 90,90,90
            vignette: Color 80,80,80
            traced: Color 200, 120, 0
            untraced: Color 32,32,32
        }
        :cells
        :vpaths
        :hpaths
        :intersections
    }