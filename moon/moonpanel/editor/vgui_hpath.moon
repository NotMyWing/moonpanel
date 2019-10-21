hpath = {}

white = Color 255, 255, 255

hpath.Init = () =>
    @type = Moonpanel.ObjectTypes.HPath

types = Moonpanel.EntityTypes
hexagon = Material "moonpanel/common/hexagon.png"
hexagon_hollow = Material "moonpanel/common/hexagon_hollow.png"

hpath.Paint = (w, h) =>
    surface.SetDrawColor @panel.data.colors.untraced or Moonpanel.DefaultColors.Untraced
    if @entity == types.Hexagon or not @entity
        surface.DrawRect 0, 0, w, h

        if @entity == types.Hexagon      
            innerw = math.min w, h
            innerh = innerw

            surface.SetDrawColor Moonpanel.Colors[@attributes.color or Moonpanel.Color.Black]
            surface.SetMaterial @attributes.hollow and hexagon_hollow or hexagon
            surface.DrawTexturedRect (w/2) - (innerw/2), (h/2) - (innerh/2), innerw, innerh

    elseif @entity == types.Disjoint
        pct = @panel.data.disjointLength or 0.25

        innerwidth = w * pct
        step = math.ceil((w - innerwidth) / 2)
        surface.DrawRect 0, 0, step, h
        surface.DrawRect step + innerwidth, 0, step, h

return vgui.RegisterTable hpath, "DButton"