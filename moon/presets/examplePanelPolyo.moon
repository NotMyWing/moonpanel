--@include moonpanel/core/moonpanel.txt

tile = require "moonpanel/core/moonpanel.txt"

if SERVER
    cells = {
        {
            x: 1
            y: 1
            type: "Polyomino"
            attributes: {
                shape: {
                    {1, 1}
                    {1, 1}
                }
            }
            rotational: false
        }
        {
            x: 2
            y: 1
            type: "Polyomino"
            attributes: {
                shape: {
                    {1, 1}
                    {1, 1}
                }
            }
            rotational: false
        }
        {
            x: 3
            y: 1
            type: "Polyomino"
            attributes: {
                shape: {
                    {1, 1}
                    {1, 1}
                }
            }
            rotational: false
        }
        {
            x: 1
            y: 2
            type: "Polyomino"
            attributes: {
                shape: {
                    {1, 1}
                    {1, 1}
                }
            }
            rotational: false
        }
        {
            x: 2
            y: 2
            type: "Polyomino"
            attributes: {
                shape: {
                    {1, 1}
                    {1, 1}
                }
            }
            rotational: false
        }
        {
            x: 3
            y: 2
            type: "Polyomino"
            attributes: {
                shape: {
                    {1, 1}
                    {1, 1}
                }
            }
            rotational: false
        }
        {
            x: 1
            y: 3
            type: "Polyomino"
            attributes: {
                shape: {
                    {1, 1}
                    {1, 1}
                }
            }
            rotational: false
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
            rotational: false
        }
        {
            x: 3
            y: 3
            type: "Polyomino"
            attributes: {
                shape: {
                    {1, 1}
                    {1, 1}
                }
            }
            rotational: false
        }
        {
            x: 1
            y: 4
            type: "Polyomino"
            attributes: {
                shape: {
                    {1, 1}
                    {1, 1}
                }
            }
            rotational: false
        }
        {
            x: 2
            y: 4
            type: "Y"
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
            x: 7
            y: 1
            type: "Exit"
        }
    }

    tile\setup {
        :intersections
        :cells
        tile: {
            width: 6
            height: 6
        }
    }