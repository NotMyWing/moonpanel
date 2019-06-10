--@include moonpanel/core/elements.txt
export SCREEN_WIDTH = 512
export SCREEN_HEIGHT = 512

export ROTATIONAL_SYMMETRY = 1
export VERTICAL_SYMMETRY = 2
export HORIZONTAL_SYMMETRY = 3

export COLOR_BLACK   = 1
export COLOR_WHITE   = 2
export COLOR_CYAN    = 3
export COLOR_MAGENTA = 4
export COLOR_YELLOW  = 5
export COLOR_RED     = 6
export COLOR_GREEN   = 7
export COLOR_BLUE    = 8
export COLOR_ORANGE  = 9

export COLORS = {
    Color 0, 0, 0 
    Color 255, 255, 255
    Color 0, 255, 255
    Color 255, 0, 255
    Color 255, 255, 0
    Color 255, 0, 0
    Color 0, 128, 0
    Color 0, 0, 255
    Color 255, 160, 0
}

require "moonpanel/core/elements.txt"

export class Rect
    new: (@x, @y, @width, @height) =>
    contains: (x, y) =>
        return x > @x and
        y > @y and
        x < @x + @width and
        y < @y + @height

return class TileShared
    buildPathMap: =>
        hpaths = {}
        vpaths = {}
        @pathMap = {}
        width = @tileData.dimensions.width
        height = @tileData.dimensions.height

        for i = 1, width + 1
            translatedX = (i - 1) - (width / 2)
            for j = 1, height + 1
                translatedY = (j - 1) - (height / 2)
                intersection = @elements.intersections[i][j]
                
                clickable = false
                for k, v in pairs intersection.objects
                    if v.type == "Entrance"
                        clickable = true
                        break

                node = {
                    x: translatedX
                    y: translatedY
                    :intersection
                    :clickable
                    screenX: intersection.bounds.x + intersection.bounds.width / 2
                    screenY: intersection.bounds.y + intersection.bounds.height / 2
                    neighbors: {}
                }
                table.insert @pathMap, node

                intersection.pathMapNode = node
                intersection\populatePathMap @pathMap

        if (@tileData.tile.symmetry or 0) == 0
            for i = 1, width
                for j = 1, height + 1
                    hpath = @elements.hpaths[i][j]
                    hpath\populatePathMap @pathMap
            for i = 1, width + 1
                for j = 1, height
                    vpath = @elements.vpaths[i][j]
                    vpath\populatePathMap @pathMap

    processElements: =>
        width = @tileData.dimensions.width
        height = @tileData.dimensions.height
        barWidth = @tileData.dimensions.barWidth
        barLength = @tileData.dimensions.barLength
        offsetH = @tileData.dimensions.offsetH
        offsetV = @tileData.dimensions.offsetV

        @elements = {}

        @elements.cells = {}
        for i = 1, width
            @elements.cells[i] = {}
            for j = 1, height
                cell = Cell @, i, j
                x = offsetH + barWidth + (i - 1) * (barLength + barWidth)
                y = offsetV + barWidth + (j - 1) * (barLength + barWidth)
                cell.bounds = Rect x, y, barLength, barLength

                @elements.cells[i][j] = cell

        for k, v in pairs (@tileData.cells or {})
            cell = (@elements.cells[v.x] or {})[v.y]
            if not cell
                continue

            obj = CELL_OBJECTS[v.type] cell, v.attributes
            obj.attributes.type = v.type

            table.insert cell.objects, obj
            break

        @elements.hpaths = {}
        for i = 1, width
            @elements.hpaths[i] = {}
            for j = 1, height + 1
                hpath = HPath @, i, j
                x = offsetH + barWidth + (i - 1) * (barLength + barWidth)
                y = offsetV + (j - 1) * (barLength + barWidth)
                hpath.bounds = Rect x, y, barLength, barWidth

                @elements.hpaths[i][j] = hpath

        for k, v in pairs (@tileData.hpaths or {})
            hpath = (@elements.hpaths[v.x] or {})[v.y]
            if not hpath
                continue

            obj = HPATH_OBJECTS[v.type] hpath, v.attributes
            obj.attributes.type = v.type

            table.insert hpath.objects, obj
            break

        @elements.vpaths = {}
        for i = 1, width + 1
            @elements.vpaths[i] = {}
            for j = 1, height
                vpath = VPath @, i, j
                y = offsetV + barWidth + (j - 1) * (barLength + barWidth)
                x = offsetH + (i - 1) * (barLength + barWidth)
                vpath.bounds = Rect x, y, barWidth, barLength

                @elements.vpaths[i][j] = vpath

        for k, v in pairs (@tileData.vpaths or {})
            vpath = (@elements.vpaths[v.x] or {})[v.y]
            if not vpath
                continue

            obj = VPATH_OBJECTS[v.type] vpath, v.attributes
            obj.attributes.type = v.type

            table.insert vpath.objects, obj
            break

        @elements.intersections = {}
        for i = 1, width + 1
            @elements.intersections[i] = {}
            for j = 1, height + 1
                int = Intersection @, i, j
                x = offsetH + (i - 1) * (barLength + barWidth)
                y = offsetV + (j - 1) * (barLength + barWidth)
                int.bounds = Rect x, y, barWidth, barWidth

                @elements.intersections[i][j] = int

        for k, v in pairs (@tileData.intersections or {})
            intersection = (@elements.intersections[v.x] or {})[v.y]
            if not intersection
                continue

            obj = INTERSECTION_OBJECTS[v.type] intersection, v.attributes
            obj.attributes.type = v.type

            table.insert intersection.objects, obj
            break

        @buildPathMap!

    new: () =>