--@include moonpanel/core/moonpanel.txt

tile = require "moonpanel/core/moonpanel.txt"

if SERVER
    width = 5
    height = 4
    cells = {
        { 
            x: 1,
            y: 1,
            type: "Sun",
            attributes: {
                color: 1,
                r: 230,
                g: 1,
                b: 250
            }
        },
        { 
            x: 2,
            y: 1,
            type: "Sun",
            attributes: {
                color: 1,
                r: 230,
                g: 1,
                b: 250
            }
        },
        { 
            x: 3,
            y: 1,
            type: "Color",
            attributes: {
                color: 2,
                r: 116,
                g: 230,
                b: 45
            }
        },
        { 
            x: 3,
            y: 2,
            type: "Color",
            attributes: {
                color: 2,
                r: 116,
                g: 230,
                b: 45
            }
        },
        { 
            x: 2,
            y: 2,
            type: "Color",
            attributes: {
                color: 2,
                r: 116,
                g: 230,
                b: 45
            }
        },
        { 
            x: 1,
            y: 2,
            type: "Color",
            attributes: {
                color: 2,
                r: 116,
                g: 230,
                b: 45
            }
        },
        { 
            x: 1,
            y: 3,
            type: "Sun",
            attributes: {
                color: 1,
                r: 230,
                g: 1,
                b: 250
            }
        },
        { 
            x: 1,
            y: 2,
            type: "Color",
            attributes: {
                color: 2,
                r: 116,
                g: 230,
                b: 45
            }
        },
        { 
            x: 1,
            y: 4,
            type: "Color",
            attributes: {
                color: 3,
                r: 238,
                g: 130,
                b: 22
            }
        },
        { 
            x: 2,
            y: 4,
            type: "Color",
            attributes: {
                color: 3,
                r: 238,
                g: 130,
                b: 22
            }
        },
        { 
            x: 2,
            y: 3,
            type: "Sun",
            attributes: {
                color: 1,
                r: 230,
                g: 1,
                b: 250
            }
        },
        { 
            x: 4,
            y: 2,
            type: "Sun",
            attributes: {
                color: 1,
                r: 230,
                g: 1,
                b: 250
            }
        },
        { 
            x: 4,
            y: 3,
            type: "Sun",
            attributes: {
                color: 1,
                r: 230,
                g: 1,
                b: 250
            }
        },
        { 
            x: 5,
            y: 2,
            type: "Color",
            attributes: {
                color: 3,
                r: 238,
                g: 130,
                b: 22
            }
        },
        { 
            x: 5,
            y: 3,
            type: "Color",
            attributes: {
                color: 3,
                r: 238,
                g: 130,
                b: 22
            }
        },
    }

    vpaths = {
        {
            x: 5,
            y: 3,
            type: "Broken"
        },
    }
    hpaths = {
        {
            x: 2,
            y: 4,
            type: "Broken"
        },
    }

    intersections = {
        {
            x: 6,
            y: 5,
            type: "Entrance"
        },
        {
            x: 1,
            y: 1,
            type: "Exit",
        }
    }

    tile\setup {
        tile: {
            :width
            :height
            innerScreenRatio: 0.85
            barWidth: 35
        }
        colors: {
            background: Color 90,90,90
            vignette: Color 80,80,80
            traced: Color 255, 0, 255
            untraced: Color 32,32,32
        }
        :cells
        :vpaths
        :hpaths
        :intersections
    }