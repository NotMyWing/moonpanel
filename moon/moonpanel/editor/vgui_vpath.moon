vpath = {}

white = Color 255, 255, 255

vpath.Init = () =>
    @type = Moonpanel.ObjectTypes.VPath

types = Moonpanel.EntityTypes
hexagon = Material "moonpanel/hexagon.png"

vpath.Paint = (w, h) =>
    surface.SetDrawColor @panel.data.colors.untraced or Moonpanel.DefaultColors.Untraced
    if @entity == types.Hexagon or not @entity
        surface.DrawRect 0, 0, w, h

        if @entity == types.Hexagon
            innerw = math.min w, h
            innerh = innerw

            surface.SetDrawColor Moonpanel.Colors[@attributes.color or Moonpanel.Color.Black]
            surface.SetMaterial hexagon
            surface.DrawTexturedRect (w/2) - (innerw/2), (h/2) - (innerh/2), innerw, innerh

    elseif @entity == types.Disjoint
        pct = @panel.data.disjointLength or 0.25

        innerheight = h * pct
        step = math.ceil((h - innerheight) / 2)
        surface.DrawRect 0, 0, w, step
        surface.DrawRect 0, step + innerheight, w, step 

return vgui.RegisterTable vpath, "DButton"