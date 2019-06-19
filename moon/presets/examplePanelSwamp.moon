--@include moonpanel/core/moonpanel.txt

tile = require "moonpanel/core/moonpanel.txt"

if SERVER
    cells = {
        {
            x: 2
            y: 1
            type: "Polyomino"
            attributes: {
                shape: {
                    {1, 1, 1}
                    {0, 0, 1}
                }
            }
        }
        {
            x: 2
            y: 3
            type: "Polyomino"
            attributes: {
                shape: {
                    {1, 1}
                    {1, 1}
                }
            }
        }
        {
            x: 4
            y: 3
            type: "Polyomino"
            attributes: {
                shape: {
                    {1, 0}
                    {1, 1}
                    {0, 1}
                }
            }
        }
        {
            x: 5
            y: 3
            type: "Polyomino"
            attributes: {
                shape: {
                    {1}
                    {1}
                    {1}
                    {1}
                }
            }
        }
        {
            x: 1
            y: 4
            type: "Polyomino"
            attributes: {
                shape: {
                    {1, 1, 1}
                    {1, 0, 0}
                }
            }
        }
        {
            x: 2
            y: 6
            type: "Polyomino"
            attributes: {
                shape: {
                    {0, 1, 0}
                    {1, 1, 1}
                }
            }
        }
        {
            x: 4
            y: 6
            type: "Polyomino"
            attributes: {
                shape: {
                    {1, 1, 0}
                    {0, 1, 1}
                }
            }
        }
    }

    vpaths = {
    }

    intersections = {
        {
            x: 1
            y: 7
            type: "Entrance"
        }
        {
            x: 6
            y: 1
            type: "Exit"
        }
    }

    tile\setup {
        :intersections
        :cells
        tile: {
            width: 5
            height: 6
        }
    }