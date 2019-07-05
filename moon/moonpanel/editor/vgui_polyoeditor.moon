polyoeditor = {}

polyoeditor.Setup = (@data) =>
    @data.w or= 5
    @data.h or= 5

    for j, row in pairs @rows
        children = row\GetChildren!
        for i = 1, #children
            children[i].checked = @data[j] and @data[j][i]

polyoeditor.Paint = (w, h) =>
    if not @headerH
        return

    draw.RoundedBoxEx 4, 0, 0, w, @headerH, (Color  128, 128, 128, 255), true, true, false, false

    draw.RoundedBoxEx 4, 0, @headerH, w, h - @headerH, (Color 90, 90, 90), false, false, true, true

polyoeditor.Init = () =>
    @headerH = @GetTall!
    with @
        \SetWide 150
        \SetTall 150
        \SetTitle ""
        \SetDeleteOnClose true
        \DockPadding 0, 24, 0, 0
        \SetDraggable true 

    @rows = {}
    for j = 1, 5
        row = vgui.Create "DPanel", @
        row\Dock TOP
        row\SetTall 30
        row\SetWide 0
        @rows[#@rows + 1] = row
        for i = 1, 5
            button = vgui.Create "DButton", row
            button\SetText ""
            button\SetWide 30
            button\SetTall 30
            button\Dock LEFT
            button.DoClick = (_self) ->
                _self.checked = not _self.checked
                if @data
                    @data[j] or= {}
                    @data[j][i] = _self.checked

            button.Paint = (w, h) =>
                if not @checked
                    surface.SetAlphaMultiplier 0.1
                surface.SetDrawColor Moonpanel.Colors[Moonpanel.Color.Yellow]
                innerw = w * 0.85
                innerh = h * 0.85
                surface.DrawRect (w/2) - (innerw/2), (h/2) - (innerh/2), innerw, innerh
                if not @checked
                    surface.SetAlphaMultiplier 1

        row\InvalidateLayout true
        row.Paint = nil
    
    fixedRow = vgui.Create "DPanel", @
    fixedRow.Paint = nil
    fixedRow\Dock TOP
    fixedRow\SetTall 28
    @rows[#@rows + 1] = fixedRow

    checkbox = vgui.Create "DCheckBoxLabel", fixedRow 
    with checkbox
        \SetText "Rotational"
        \Dock BOTTOM
        \SizeToContents!
        \DockMargin 10, 0, 4, 4
        .OnChange = (_, val) ->
            @data.rotational = val

    timer.Simple 0, () ->
        for _, row in pairs @GetChildren!
            row\SizeToChildren true, true
        @InvalidateLayout true
        timer.Simple 0, () ->
            @SizeToChildren true, true

return vgui.RegisterTable polyoeditor, "DFrame"