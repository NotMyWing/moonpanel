vpath = {}

white = Color 255, 255, 255

vpath.Init = () =>
    @type = MOONPANEL_OBJECT_TYPES.VPATH

types = MOONPANEL_ENTITY_TYPES
hexagon = Material "moonpanel/hexagon.png"

vpath.Paint = (w, h) =>
    surface.SetDrawColor white
    if @entity == types.HEXAGON or not @entity
        surface.DrawRect 0, 0, w, h

        if @entity == types.HEXAGON 
            innerw = math.min w, h
            innerh = innerw

            surface.SetDrawColor 60, 60, 60
            surface.SetMaterial hexagon
            surface.DrawTexturedRect (w/2) - (innerw/2), (h/2) - (innerh/2), innerw, innerh

    elseif @entity == types.DISJOINT
        pct = @panel.data.disjointLength or 0.25

        innerheight = h * pct
        step = math.ceil((h - innerheight) / 2)
        surface.DrawRect 0, 0, w, step
        surface.DrawRect 0, step + innerheight, w, step 

return vgui.RegisterTable vpath, "DButton"