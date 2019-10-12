cell = {}

types = Moonpanel.EntityTypes
graphics = MOONPANEL_ENTITY_GRAPHICS
white = Color 255, 255, 255

cell.Init = () =>
    @type = Moonpanel.ObjectTypes.Cell

polyocell = Material "moonpanel/common/polyomino_cell.png", "smooth"
triangle = Material "moonpanel/common/triangle.png"
cross = Material "moonpanel/editor/cross.png"

cell.RenderTriangles = (w, h, count) =>
    surface.SetDrawColor Moonpanel.Colors[@attributes.color or Moonpanel.Color.Yellow]
    surface.SetMaterial triangle
    innerw = w * 0.275
    innerh = h * 0.275

    shrink = w * 0.8

    triangleWidth = w * 0.2
    spacing = w * 0.11
    offset = if count == 1
        0
    else
        (((count - 1) * triangleWidth) + ((count - 1) * spacing)) / 2

    matrix = Matrix!
    matrix\Translate Vector (w / 2) - offset, h / 2, 0
    
    surface.DisableClipping true
    for i = 1, count do
        if i > 1
            cam.PopModelMatrix!
            matrix\Translate Vector triangleWidth + spacing, 0, 0

        cam.PushModelMatrix matrix
        surface.DrawTexturedRect -(innerw/2), -(innerh/2), innerw, innerh
    surface.DisableClipping false
    cam.PopModelMatrix!

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
        render.PushFilterMag TEXFILTER.LINEAR
        render.PushFilterMin TEXFILTER.LINEAR
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
        
    surface.SetMaterial polyocell
    for j = 1, polyheight
        for i = 1, polywidth
            if data.shape[j] and data.shape[j][i]
                x = offsetX + (i - 1) * spacing + (i - 1) * squareWidth 
                y = offsetY + (j - 1) * spacing + (j - 1) * squareWidth 
                --draw.RoundedBox 4, x, y, squareWidth, squareWidth, Moonpanel.Colors[data.color]
                surface.DrawTexturedRect x, y, squareWidth, squareWidth, Moonpanel.Colors[data.color]
    
    if data.shape.rotational
        cam.PopModelMatrix!
        render.PopFilterMag!
        render.PopFilterMin!

cell.Paint = (w, h) =>  
    if not @entity
        return

    render.PushFilterMag TEXFILTER.ANISOTROPIC
    render.PushFilterMin TEXFILTER.ANISOTROPIC

    if @attributes.color
        surface.SetDrawColor Moonpanel.Colors[@attributes.color]
    else
        surface.SetDrawColor white

    if @entity == types.Polyomino
        @RenderPolyo w, h
        
    elseif @entity == types.Triangle
        @RenderTriangles w, h, @attributes.count

    elseif @entity == types.Invisible
        surface.SetDrawColor white
        surface.SetMaterial cross
        surface.DrawTexturedRect 0, 0, w, h

    elseif graphics[@entity]
        surface.SetMaterial graphics[@entity]
        surface.DrawTexturedRect 0, 0, w, h

    render.PopFilterMag!
    render.PopFilterMin!

return vgui.RegisterTable cell, "DButton"