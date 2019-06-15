--@include moonpanel/core/moonpanel.txt

tile = require "moonpanel/core/moonpanel.txt"

if SERVER
    cells = {
        {
            x: 1
            y: 1
            type: "Sun"
            attributes: {
                color: COLOR_ORANGE
            }
        }
        {
            x: 2
            y: 1
            type: "Sun"
            attributes: {
                color: COLOR_ORANGE
            }
        }
        {
            x: 1
            y: 2
            type: "Sun"
            attributes: {
                color: COLOR_ORANGE
            }
        }
        {
            x: 2
            y: 2
            type: "Sun"
            attributes: {
                color: COLOR_ORANGE
            }
        }
    }
    intersections = {
        {
            x: 2
            y: 3
            type: "Entrance"
        }
        {
            x: 2
            y: 1
            type: "Exit"
        }
    }

    hpaths = {
        {
            x: 2
            y: 2
            type: "Broken"
        }
    }

    width = 2
    height = 2

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