--@include moonpanel/core/moonpanel.txt

tile = require "moonpanel/core/moonpanel.txt"

if SERVER
    width = 3
    height = 3 
    cells = {
        {
            x: 2
            y: 2
            type: "Y"
        }
    }

    intersections = {
        {
            x: 1
            y: 4
            type: "Entrance"
        }
        {
            x: 4
            y: 1
            type: "Exit"
        }
        {
            x: 2
            y: 2
            type: "Dot"
        } 
        {
            x: 2
            y: 3
            type: "Dot"
        } 
        {
            x: 4
            y: 2
            type: "Dot"
        } 
        {
            x: 3
            y: 3
            type: "Dot"
        } 
    }

    vpaths = {
        {
            x: 2
            y: 1
            type: "Dot"
        }
        {
            x: 2
            y: 3
            type: "Dot"
        }
        {
            x: 3
            y: 3
            type: "Dot"
        }
        {
            x: 4
            y: 2
            type: "Dot"
        }
    }

    hpaths = {
        {
            x: 3
            y: 3
            type: "Broken"
        }
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