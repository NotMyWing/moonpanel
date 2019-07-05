cell = {}

types = MOONPANEL_ENTITY_TYPES
graphics = MOONPANEL_ENTITY_GRAPHICS
white = Color 255, 255, 255

cell.Init = () =>
    @type = MOONPANEL_OBJECT_TYPES.CELL

cell.RenderTriangles = (w, h, count) =>


cell.RenderPolyo = (w, h) =>
    data = @attributes
    if not data
        return

    polyheight = data.shape.h
    polywidth = data.shape.w

    maxDim = math.max polyheight, polywidth
    shrink = w * 0.8

    if data.rotational
        shrink *= 0.7

    squareWidth = math.min shrink / maxDim, w * 0.2
    spacing = shrink * 0.025

    offsetX = (w / 2) - ((squareWidth * polywidth ) + ((polywidth  - 1) * spacing)) / 2
    offsetY = (h / 2) - ((squareWidth * polyheight) + ((polyheight - 1) * spacing)) / 2

    if data.shape.rotational
        render.PushFilterMag TEXFILTER.ANISOTROPIC
	    render.PushFilterMin TEXFILTER.ANISOTROPIC
        v = Vector w / 2, h / 2, 0

        matrix = Matrix!
        
        gx, gy = @LocalToScreen 0, 0
        gv = Vector gx, gy, 0
        matrix\Translate gv
        matrix\Translate v
        matrix\Rotate Angle 0, -20, 0
        matrix\Translate -v
        matrix\Translate -gv

        cam.PushModelMatrix matrix 
        
    for j = 1, polyheight
        for i = 1, polywidth
            if data.shape[j] and data.shape[j][i]
                x = offsetX + (i - 1) * spacing + (i - 1) * squareWidth 
                y = offsetY + (j - 1) * spacing + (j - 1) * squareWidth 
                draw.RoundedBox 4, x, y, squareWidth, squareWidth, Moonpanel.Colors[data.color]
    
    if data.shape.rotational
        cam.PopModelMatrix!
        render.PopFilterMag!
        render.PopFilterMin!

cell.Paint = (w, h) =>
    if not @entity
        return
        
    if @attributes.color
        surface.SetDrawColor Moonpanel.Colors[@attributes.color]
    else
        surface.SetDrawColor white

    if @entity == types.POLYOMINO
        @RenderPolyo w, h
        
    elseif @entity == types.TRIANGLE
        @RenderTriangles

    elseif graphics[@entity]
        surface.SetMaterial graphics[@entity]
        surface.DrawTexturedRect 0, 0, w, h

return vgui.RegisterTable cell, "DButton"