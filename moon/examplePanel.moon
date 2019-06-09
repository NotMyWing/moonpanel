--@include moonpanel/core/moonpanel.txt

tile = require "moonpanel/core/moonpanel.txt"

if SERVER
    cells = {
        {
            x: 1
            y: 1
            type: "Color"
            attributes: {
                r: 255
                g: 0
                b: 0
                group: 1
            }
        }
        {
            x: 1
            y: 2
            type: "Color"
            attributes: {
                r: 0
                g: 0
                b: 255
                group: 1
            }
        }
        {
            x: 2
            y: 1
            type: "Color"
            attributes: {
                r: 0
                g: 255
                b: 0
                group: 1
            }
        }
    }

    vpaths = {
        {
            x: 1
            y: 1
            type: "Invisible"
        }
    }

    tile\setup {
        :cells
        :vpaths
    }