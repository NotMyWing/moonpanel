panel = {}

backgroundImages = {
    ["default"]: {
        outDimension: { w: 1474, h: 1474 }
        inDimension: { w: 1024, h: 1024 }
        path: Material "moonpanel/editor/panel.png"
    }
}

vignette = Material "moonpanel/common/vignette.png"
panel.Init = () =>
    @centerPanel = vgui.Create "DPanel", @
    @centerPanel.Paint = (_, w, h) -> 
        surface.SetDrawColor (@data and @data.colors and @data.colors.background) or Moonpanel.DefaultColors.Background
        neww = math.min w, h
        surface.DrawRect (w/2) - (neww/2), (h/2) - (neww/2), neww, neww

        surface.SetDrawColor (@data and @data.colors and @data.colors.vignette) or Moonpanel.DefaultColors.Vignette
        surface.SetMaterial vignette
        surface.DrawTexturedRect (w/2) - (neww/2), (h/2) - (neww/2), neww, neww

    @centerPanel\SetZPos -2

    @centerPanel.PerformLayout = (_, w, h) ->
        if not w or not h or not @background or not @data or not @rows or not @puzzlePanel
            return

        @calculatedDimensions = Moonpanel\calculateDimensionsShared {
            screenW: w
            screenH: h
            cellsW: @data.w
            cellsH: @data.h
            innerScreenRatio: @data.innerScreenRatio
            maxBarLength: @data.maxBarLength
            barWidth: @data.barWidth
        }

        @puzzlePanel\SetWide @calculatedDimensions.innerWidth
        @puzzlePanel\SetTall @calculatedDimensions.innerHeight

        @puzzlePanel\Center!

        for j, row in pairs @rows
            if j % 2 == 0
                row\SetTall @calculatedDimensions.barLength
            else
                row\SetTall @calculatedDimensions.barWidth
            for i, child in pairs row\GetChildren!
                if i % 2 == 0
                    child\SetWide @calculatedDimensions.barLength
                else
                    child\SetWide @calculatedDimensions.barWidth

        for j, row in pairs @rows
            row\InvalidateLayout!

    @puzzlePanel = vgui.Create "DPanel", @centerPanel
    @puzzlePanel.Paint = (_, w, h) ->
        surface.SetDrawColor @data.colors.cell
        draw.NoTexture!
        if @__flatCells
            for _, cell in pairs @__flatCells
                if cell.entity == Moonpanel.EntityTypes.Invisible
                    continue

                surface.DisableClipping true
                barw = @calculatedDimensions.barWidth
                cx, cy, cw, ch = cell\GetBounds!
                rx, ry = cell.row\GetPos!
                rx += cx
                ry += cy

                surface.DrawRect rx - barw / 2, ry - barw / 2, cw + barw, ch + barw
                surface.DisableClipping false

panel.Paint = (w, h) =>
    if @background and @background.path
        surface.SetMaterial @background.path
        surface.SetDrawColor 255, 255, 255, 255
        neww = math.min w, h
        surface.DrawTexturedRect (w/2) - (neww/2), (h/2) - (neww/2), neww, neww

panel.Setup = (@data = {}, __clickCallback, __copyCallback) =>
    @background = backgroundImages[@data.bg or "default"]

    if __clickCallback
        @clickCallback = __clickCallback

    if __copyCallback
        @copyCallback = __copyCallback

    @data.w or= 3
    @data.h or= 3
    @puzzlePanel\Clear!
    @rows = {}
    for i = 1, (@data.h * 2) + 1
        @rows[i] = vgui.Create "DPanel", @puzzlePanel
        @rows[i]\Dock TOP
        @rows[i].Paint = () ->

    @__flatCells = {}

    @cells = {}
    @vpaths = {}
    @hpaths = {}
    @intersections = {}
    for j, row in pairs @rows
        for i = 1, (@data.w * 2) + 1
            element = nil
            if j % 2 == 0
                if i % 2 == 0
                    element = vgui.CreateFromTable (include "moonpanel/editor/vgui_cell.lua"), row
                    @__flatCells[#@__flatCells + 1] = element

                    x, y = i / 2, j / 2
                    @cells[y] or= {}
                    @cells[y][x] = element
                    element.x, element.y = x, y

                    if @data.cells and @data.cells[y] and @data.cells[y][x]
                        element.entity = @data.cells[y][x].entity
                        element.attributes = @data.cells[y][x].attributes
                else
                    element = vgui.CreateFromTable (include "moonpanel/editor/vgui_vpath.lua"), row

                    x, y = math.floor(i / 2) + 1, j / 2
                    @vpaths[y] or= {}
                    @vpaths[y][x] = element
                    element.x, element.y = x, y

                    if @data.vpaths and @data.vpaths[y] and @data.vpaths[y][x]
                        element.entity = @data.vpaths[y][x].entity
                        element.attributes = @data.vpaths[y][x].attributes
            else
                if i % 2 == 0
                    element = vgui.CreateFromTable (include "moonpanel/editor/vgui_hpath.lua"), row

                    x, y = i / 2, math.floor(j / 2) + 1
                    @hpaths[y] or= {}
                    @hpaths[y][x] = element
                    element.x, element.y = x, y

                    if @data.hpaths and @data.hpaths[y] and @data.hpaths[y][x]
                        element.entity = @data.hpaths[y][x].entity
                        element.attributes = @data.hpaths[y][x].attributes
                else
                    element = vgui.CreateFromTable (include "moonpanel/editor/vgui_intersection.lua"), row

                    element.corner = (j == 1 and i == 1) and 1 or
                        (j == (@data.h * 2 + 1) and i == 1) and 2 or 
                        (j == 1 and i == (@data.w * 2 + 1)) and 4 or
                        (j == (@data.h * 2 + 1) and i == (@data.w * 2 + 1)) and 3 or nil
                    element.i, element.j = math.floor(i / 2) + 1, math.floor(j / 2) + 1

                    x, y = math.floor(i / 2) + 1, math.floor(j / 2) + 1
                    @intersections[y] or= {}
                    @intersections[y][x] = element

                    element.x, element.y = x, y

                    if @data.intersections and @data.intersections[y] and @data.intersections[y][x]
                        entity = @data.intersections[y][x].entity

                        --if entity == Moonpanel.EntityTypes.End
                        --    if (i > 1) and (j > 1) and (i < @data.w * 2) and (j < @data.h * 2)
                        --        entity = nil

                        if entity
                            element.entity = entity
                            element.attributes = @data.intersections[y][x].attributes

            element\SetText ""
            element.panel = @
            element.row = row
            element.attributes or= {}
            element.DoClick = (_) ->
                if @.clickCallback
                    @.clickCallback _
            element.DoRightClick = (_) ->
                if @.copyCallback
                    @.copyCallback _
            element\Dock LEFT

    @centerPanel\InvalidateLayout!

panel.Think = () =>

panel.PerformLayout = (w, h) =>
    if @background
        ratiow = @background.inDimension.w / @background.outDimension.w
        ratioh = @background.inDimension.h / @background.outDimension.h

        @centerPanel\SetSize w * ratiow * 1.005, h * ratioh * 1.005
        @centerPanel\Center!

    @puzzlePanel\InvalidateLayout!
    @centerPanel\InvalidateLayout!

return vgui.RegisterTable panel, "DPanel"