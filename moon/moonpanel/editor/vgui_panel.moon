panel = {}

backgroundImages = {
    ["default"]: {
        outDimension: { w: 1474, h: 1474 }
        inDimension: { w: 1024, h: 1024 }
        path: Material "moonpanel/panel_transparent_a.png"
    }
}

panel.Init = () =>
    @centerPanel = vgui.Create "DPanel", @
    @centerPanel.Paint = (w, h) =>
        surface.SetDrawColor 60, 100, 210
        neww = math.min w, h
        surface.DrawRect (w/2) - (neww/2), (h/2) - (neww/2), neww, neww
    @centerPanel\SetZPos -2

    @centerPanel.PerformLayout = (_, w, h) ->
        if not w or not h or not @background or not @data or not @rows or not @puzzlePanel
            return

        maxCellDimension = math.max @data.w, @data.h
        minCellDimension = math.min @data.w, @data.h 

        resolution = MOONPANEL_DEFAULT_RESOLUTIONS[maxCellDimension] or MOONPANEL_DEFAULTEST_RESOLUTION

        minPanelDimension = (math.min w, h) * (@data.innerScreenRatio or resolution.innerScreenRatio)

        barWidth = (@data.barWidth or resolution.barWidth) * minPanelDimension

        barLength = math.ceil (minPanelDimension - (barWidth * (maxCellDimension + 1))) / maxCellDimension
        barLength = math.ceil barLength - (barWidth / (math.max @data.w, @data.h))
        barLength = math.min barLength, minPanelDimension * (@data.maxBarLength or 0.25)

        @puzzlePanel\SetWide barWidth * (@data.w + 1) + barLength * (@data.w)
        @puzzlePanel\SetTall barWidth * (@data.h + 1) + barLength * (@data.h)

        @puzzlePanel\Center!

        for j, row in pairs @rows
            if j % 2 == 0
                row\SetTall barLength
            else
                row\SetTall barWidth
            for i, child in pairs row\GetChildren!
                if i % 2 == 0
                    child\SetWide barLength
                else
                    child\SetWide barWidth

        for j, row in pairs @rows
            row\InvalidateLayout!

    @puzzlePanel = vgui.Create "DPanel", @centerPanel
    @puzzlePanel.Paint = nil

panel.Paint = (w, h) =>
    if @background and @background.path
        surface.SetMaterial @background.path
        surface.SetDrawColor 255, 255, 255
        neww = math.min w, h
        surface.DrawTexturedRect (w/2) - (neww/2), (h/2) - (neww/2), neww, neww

panel.Setup = (@data = {}, __clickCallback) =>
    @background = backgroundImages[@data.bg or "default"]

    if __clickCallback
        @clickCallback = __clickCallback

    @data.w or= 3
    @data.h or= 3
    @puzzlePanel\Clear!
    @rows = {}
    for i = 1, (@data.h * 2) + 1
        @rows[i] = vgui.Create "DPanel", @puzzlePanel
        @rows[i]\Dock TOP
        @rows[i].Paint = () ->

    for j, row in pairs @rows
        for i = 1, (@data.w * 2) + 1
            element = nil
            if j % 2 == 0
                if i % 2 == 0
                    element = vgui.CreateFromTable (include "moonpanel/editor/vgui_cell.lua"), row

                    x, y = i / 2, j / 2
                    if @data.cells and @data.cells[y] and @data.cells[y][x]
                        element.entity = @data.cells[y][x].entity
                        element.attributes = @data.cells[y][x].attributes
                else
                    element = vgui.CreateFromTable (include "moonpanel/editor/vgui_vpath.lua"), row

                    x, y = math.floor(i / 2) + 1, j / 2
                    if @data.vpaths and @data.vpaths[y] and @data.vpaths[y][x]
                        element.entity = @data.vpaths[y][x].entity
                        element.attributes = @data.vpaths[y][x].attributes
            else
                if i % 2 == 0
                    element = vgui.CreateFromTable (include "moonpanel/editor/vgui_hpath.lua"), row

                    x, y = i / 2, math.floor(j / 2) + 1
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
                    if @data.intersections and @data.intersections[y] and @data.intersections[y][x]
                        entity = @data.intersections[y][x].entity

                        if entity == MOONPANEL_ENTITY_TYPES.END
                            if (i > 1) and (j > 1) and (i < @data.w * 2) and (j < @data.h * 2)
                                entity = nil

                        if entity
                            element.entity = entity
                            element.attributes = @data.intersections[y][x].attributes

            element\SetText ""
            element.panel = @
            element.attributes or= {}
            element.DoClick = (_) ->
                if @.clickCallback
                    @.clickCallback _
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