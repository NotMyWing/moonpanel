--@include moonpanel/core/cl_moonpanel.txt
--@include moonpanel/core/sv_moonpanel.txt
--@include moonpanel/core/cell_elements.txt

TileSided = if CLIENT
    require "moonpanel/core/cl_moonpanel.txt"
else
    require "moonpanel/core/sv_moonpanel.txt"

CELL_ELEMENTS = require "moonpanel/core/cell_elements.txt"

export COLOR_BG = Color 80, 77, 255, 255
export COLOR_UNTRACED = Color 40, 22, 186
export COLOR_TRACED = Color 255, 255, 255, 255
export COLOR_VIGNETTE = Color 0, 0, 0, 92

export SCREEN_WIDTH = 512
export SCREEN_HEIGHT = 512

export DEFAULT_SCREEN_TO_INNER_RATIO = (630-120) / 630
export DEFAULT_CEIL_TO_BAR_RATIO = 0.8
export MINIMUM_BARWIDTH = 10

class Tile extends TileSided
    elements: {
        cells: {}
        vpaths: {}
        hpaths: {}
        intersections: {}
    }
    dimensions: {}
    new: (config) =>
        super config