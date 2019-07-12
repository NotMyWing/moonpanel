intersection = {}

corner = Material "moonpanel/corner128/0.png", "noclamp smooth mips"
circle = Material "moonpanel/circ256.png", "noclamp smooth mips"

white = Color 255, 255, 255
types = Moonpanel.EntityTypes
hexagon = Material "moonpanel/hexagon.png"

intersection.Init = () =>
    @type = Moonpanel.ObjectTypes.Intersection

intersection.getAngle = (x, y, w, h) =>
    if (x == 1)
        return 90
    if (x == w)
        return 270
    if (y == 1)
        return 180
    if (y == h)
        return 0

    return -1

intersection.Paint = (w, h) =>
    surface.SetDrawColor @panel.data.colors.untraced or Moonpanel.DefaultColors.Untraced

    if @entity == Moonpanel.EntityTypes.Invisible
        return
        
    render.PushFilterMag TEXFILTER.ANISOTROPIC
    render.PushFilterMin TEXFILTER.ANISOTROPIC

    if @entity == Moonpanel.EntityTypes.Start
        surface.DisableClipping true
        surface.SetMaterial circle
        surface.DrawTexturedRectRotated math.floor(w/2), math.floor(h/2), w * 2.5, h * 2.5, 0 
        surface.DisableClipping false
    
    elseif @entity == Moonpanel.EntityTypes.End
        angle = @getAngle @i, @j, @panel.data.w + 1, @panel.data.h + 1 
        if angle ~= -1
            surface.DisableClipping true
            matrix = Matrix!
    
            gx, gy = @LocalToScreen 0, 0
            w05 = math.ceil w / 2

            gv = Vector gx + w05, gy + w05, 0 
            matrix\Translate gv
            matrix\Rotate Angle 0, angle, 0
            matrix\Translate -gv

            w15 = math.ceil w * 1.5

            matrix\Translate Vector w/2, w15, 0 

            cam.PushModelMatrix matrix

            surface.DrawRect -w05, -w15, w, w15
            surface.SetMaterial circle
            surface.DrawTexturedRect -w05, -w05, w, w
        
            cam.PopModelMatrix!
            surface.DisableClipping false

    else
        if not @corner
            surface.DrawRect 0, 0, w, h

        else
            surface.SetMaterial corner
            surface.DrawTexturedRectRotated math.floor(w/2), math.floor(h/2), w + 1, h + 1, (@corner - 1) * 90

        if @entity == types.Hexagon      
            innerw = math.min w, h
            innerh = innerw

            surface.SetDrawColor Moonpanel.Colors[@attributes.color or Moonpanel.Color.Black]
            surface.SetMaterial hexagon
            surface.DrawTexturedRect (w/2) - (innerw/2), (h/2) - (innerh/2), innerw, innerh

    render.PopFilterMag!
    render.PopFilterMin!

return vgui.RegisterTable intersection, "DButton"  