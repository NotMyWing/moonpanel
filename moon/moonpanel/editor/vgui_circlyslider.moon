circlyslider = {}

head = Material "moonpanel/editor/slider/head.png"
left = Material "moonpanel/editor/slider/left.png"
right = Material "moonpanel/editor/slider/right.png"
middle = Material "moonpanel/editor/slider/middle.png"
notch = Material "moonpanel/editor/slider/notch.png"

circlyslider.Init = () =>
    button = @\GetChildren![2]\GetChildren![1]
    button.Paint = nil
    @\GetChildren![2].Paint = (_, w, h) ->
        w -= 3
        surface.SetDrawColor 255, 255, 255, 255
        innerh = 6
        innerw = 2
        surface.SetMaterial left
        surface.DrawTexturedRect 0, (h/2) - (innerh/2), innerw, innerh
        surface.SetMaterial right
        surface.DrawTexturedRect w - innerw, (h/2) - (innerh/2), innerw, innerh
        surface.SetMaterial middle
        innerw = w - 4
        surface.DrawTexturedRect (w/2) - (innerw/2), (h/2) - (innerh/2), innerw, innerh

        bx, by = button\GetPos!
        surface.SetDrawColor 255, 255, 255, 255
        surface.SetMaterial head
        innerh = 14
        innerw = 12
        surface.DrawTexturedRect bx, (h/2) - (innerh/2), innerw, innerh

        w -= 7
        notches = (@.GetNotches and @GetNotches!) or 10
        step = w / (notches - 1)
        surface.SetMaterial notch
        surface.SetRenderColor

        hoffset = h / 2 + h * 0.15 
        for i = 1, notches
            surface.DrawTexturedRect 2 + step * (i-1), hoffset, 3, 7
        

circlyslider.Think = () =>

return vgui.RegisterTable circlyslider, "DNumSlider"