--@include moonpanel/core/moonpanel.txt

tile = require "moonpanel/core/moonpanel.txt"

if SERVER
    width = 3
    height = 3
    cells = {
        { 
            x: 1,
            y: 1,
            type: "Sun",
            attributes: {
                color: COLOR_ORANGE
            }
        },
        { 
            x: 3,
            y: 3,
            type: "Sun",
            attributes: {
                color: COLOR_ORANGE
            }
        }
    }

    vpaths = {
        {
            x: 1,
            y: 1,
            type: "Broken"
        },
        {
            x: 4,
            y: 1,
            type: "Broken"
        }
    }
    hpaths = {
        {
            x: 1,
            y: 3,
            type: "Broken"
        },
        {
            x: 1,
            y: 4,
            type: "Broken"
        },
        {
            x: 3,
            y: 3,
            type: "Broken"
        }
    }

    intersections = {
        {
            x: 3,
            y: 4,
            type: "Entrance"
        },
        {
            x: 3,
            y: 1,
            type: "Exit",
        },
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