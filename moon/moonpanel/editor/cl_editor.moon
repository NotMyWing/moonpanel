editor = {}

updateDirRecur = (path) =>
editor.UpdateTree = () =>
    @tree\Clear!

    node = @tree\AddNode "moonpanel"
    node\MakeFolder "moonpanel", "DATA", true
    node\SetExpanded true
    node.isRoot = true

normalize = (t) ->
    norm = {}
    minx, miny, maxx, maxy = nil, nil, nil, nil
    for j = 1, 5
        for i = 1, 5
            if t[j] and t[j][i]
                if not maxy or j > maxy
                    maxy = j
                if not miny or j < miny
                    miny = j
                if not maxx or i > maxx
                    maxx = i
                if not minx or i < minx
                    minx = i

    if not minx
        return

    norm.w = maxx - minx + 1
    norm.h = maxy - miny + 1
    norm.rotational = t.rotational

    for j = 1, norm.h
        norm[j] = {}
        for i = 1, norm.w
            if t[j + miny - 1]
                norm[j][i] = t[j + miny - 1][i + minx - 1]

    return norm

comparePolyos = (a, b) ->
    if a.w ~= b.w or a.h ~= b.h
        return false

    for i = 1, a.h
        for j = 1, a.w
            if a[j][i] ~= b[j][i]
                return false
    
    return true

gfx = {
    [MOONPANEL_ENTITY_TYPES.POLYOMINO]: (Material "moonpanel/polyo.png", "noclamp smooth")
    [MOONPANEL_ENTITY_TYPES.SUN]: (Material "moonpanel/sun.png", "noclamp smooth")
    [MOONPANEL_ENTITY_TYPES.TRIANGLE]: (Material "moonpanel/triangle.png", "noclamp smooth")
    [MOONPANEL_ENTITY_TYPES.COLOR]: (Material "moonpanel/color.png", "noclamp smooth") 
    [MOONPANEL_ENTITY_TYPES.ERASER]: (Material "moonpanel/eraser.png", "noclamp smooth")
    [MOONPANEL_ENTITY_TYPES.START]: (Material "moonpanel/start.png", "noclamp smooth")
    [MOONPANEL_ENTITY_TYPES.END]: (Material "moonpanel/end.png", "noclamp smooth")
    [MOONPANEL_ENTITY_TYPES.DISJOINT]: (Material "moonpanel/disjoint.png", "noclamp smooth")
    [MOONPANEL_ENTITY_TYPES.HEXAGON]: {
        (Material "moonpanel/hex_layer1.png", "noclamp smooth")
        (Material "moonpanel/hex_layer2.png", "noclamp smooth")
    }
}

polyoEditor = nil
polyoData = {}

white = Color 255, 255, 255

objs = MOONPANEL_OBJECT_TYPES
types = MOONPANEL_ENTITY_TYPES

prettifyFileName = (fileName) ->
    s, e = string.find fileName, "/"
    if s
        fileName = string.sub fileName, e + 1, -1

    return string.StripExtension fileName

editorEnts = {
    {
        type: types.COLOR
        tooltip: "Color"
        target: objs.CELL
        render: (w, h, color) ->
            surface.SetDrawColor color
            surface.SetMaterial gfx[types.COLOR]
            surface.DrawTexturedRect 0, 0, w, h
        set: (cell, color) ->
            if cell.attributes.color == color and cell.entity == types.COLOR
                cell.entity = nil
            else
                cell.attributes.color = color
                cell.entity = types.COLOR 
    }
    {
        type: types.SUN
        tooltip: "Sun / Star"
        target: objs.CELL
        render: (w, h, color) ->
            surface.SetDrawColor color
            surface.SetMaterial gfx[types.SUN]
            surface.DrawTexturedRect 0, 0, w, h
        set: (cell, color) ->
            if cell.attributes.color == color and cell.entity == types.SUN
                cell.entity = nil
            else
                cell.attributes.color = color
                cell.entity = types.SUN 
    }
    {
        type: types.ERASER
        tooltip: "Y-Symbol / Eraser"
        target: objs.CELL
        render: (w, h, color) ->
            surface.SetDrawColor color
            surface.SetMaterial gfx[types.ERASER]
            surface.DrawTexturedRect 0, 0, w, h
        set: (cell, color) ->
            if cell.attributes.color == color and cell.entity == types.ERASER
                cell.entity = nil
            else
                cell.attributes.color = color
                cell.entity = types.ERASER 
    }
    {
        type: types.POLYOMINO
        tooltip: "Polyomino / Tetris"
        target: objs.CELL
        render: (w, h, color) ->
            surface.SetDrawColor color
            surface.SetMaterial gfx[types.POLYOMINO]
            surface.DrawTexturedRect 0, 0, w, h
        click: (button, wasSelected) ->
            if IsValid button.polyoEditor
                button.polyoEditor\Remove!

            button.polyoEditor = vgui.CreateFromTable (include "moonpanel/editor/vgui_polyoeditor.lua")

            if IsValid button.polyoEditor
                polyoEditor = button.polyoEditor
                polyoEditor\Setup polyoData
                polyoEditor\MakePopup!
                polyoEditor\Show!
                x, y = button\LocalToScreen(0, button\GetTall!)
                polyoEditor\SetPos x, y
                polyoEditor\RequestFocus!
                timer.Simple 0.01, () ->
                    polyoEditor.Think = () ->
                        if not polyoEditor\HasFocus!
                            polyoEditor\Hide!
                            polyoEditor.Think = nil

        set: (cell, color) ->
            norm = normalize polyoData

            if not norm or 
                (cell.attributes.color == color and 
                    cell.entity == types.POLYOMINO and
                    cell.attributes.shape and
                    (comparePolyos norm, cell.attributes.shape)
                )
                cell.entity = nil
            elseif norm
                cell.attributes.color = color

                cell.attributes.shape = norm
                cell.entity = types.POLYOMINO 
    }
    {
        type: types.TRIANGLE
        tooltip: "Triangle"
        target: objs.CELL
        render: (w, h, color, button) ->
            button.count or= 1
            surface.SetDrawColor color
            surface.SetMaterial gfx[types.TRIANGLE]
            innerw = w * 0.275
            innerh = h * 0.275

            shrink = w * 0.8

            triangleWidth = w * 0.2
            spacing = w * 0.11
            offset = if button.count == 1
                0
            else
                (((button.count - 1) * triangleWidth) + ((button.count - 1) * spacing)) / 2

            matrix = Matrix!
            matrix\Translate Vector (w / 2) - offset, h / 2, 0
            
            surface.DisableClipping true
            for i = 1, button.count do
                if i > 1
                    cam.PopModelMatrix!
                    matrix\Translate Vector triangleWidth + spacing, 0, 0

                cam.PushModelMatrix matrix
                surface.DrawTexturedRect -(innerw/2), -(innerh/2), innerw, innerh
            surface.DisableClipping false
            cam.PopModelMatrix!

        click: (button, wasSelected) ->
            button.attributes.count or= 1
            if wasSelected
                button.attributes.count = (button.attributes.count % 3) + 1

        set: (cell, color) ->
            
    }
}

editorPathEnts = {
    {
        type: types.START
        tooltip: "Entrance / Start"
        target: objs.INTERSECTION
        render: (w, h, color) ->
            surface.SetDrawColor color
            surface.SetMaterial gfx[types.START]
            surface.DrawTexturedRect 0, 0, w, h
        set: (int, color) ->
            if int.entity == types.START
                int.entity = nil
            else
                int.entity = types.START 
    }
    {
        type: types.END
        tooltip: "Exit / End"
        target: objs.INTERSECTION
        render: (w, h, color) ->
            surface.SetDrawColor color
            surface.SetMaterial gfx[types.END]
            surface.DrawTexturedRect 0, 0, w, h
        set: (int, color) ->
            if int.entity == types.END
                int.entity = nil
            else
                int.entity = types.END 
    }
    {
        type: types.DISJOINT
        tooltip: "Break / Disjoint"
        target: { objs.HPATH, objs.VPATH }
        render: (w, h, color) ->
            surface.SetDrawColor color
            surface.SetMaterial gfx[types.DISJOINT]
            surface.DrawTexturedRect 0, 0, w, h
        set: (bar, color) ->
            if bar.entity == types.DISJOINT
                bar.entity = nil
            else
                bar.entity = types.DISJOINT 
    }
    {
        type: types.HEXAGON
        tooltip: "Dot / Hexagon"
        target: { objs.HPATH, objs.VPATH, objs.INTERSECTION }
        render: (w, h, color) ->
            surface.SetDrawColor color
            surface.SetMaterial gfx[types.HEXAGON][1]
            surface.DrawTexturedRect 0, 0, w, h
            surface.SetDrawColor Color 60, 60, 60
            surface.SetMaterial gfx[types.HEXAGON][2]
            surface.DrawTexturedRect 0, 0, w, h
        set: (bar, color) ->
            if bar.entity == types.HEXAGON
                bar.entity = nil
            else
                bar.entity = types.HEXAGON
    }
}

editor.clickCallback = (element) =>
    selected = nil

    fn = (btn) ->
        if btn.selected
            if type(btn.tool.target) == "table"
                for _, target in pairs btn.tool.target
                    if target == element.type
                        return btn
            else
                if btn.tool.target == element.type
                    return btn

    for k, v in pairs @__editorEnts
        val = fn v
        if val
            selected = val
            break

    if not val 
        for k, v in pairs @__editorPathEnts
            val = fn v
            if val
                selected = val
                break
    
    if not selected
        return

    element.attributes or= {}
    selected.tool.set element, @selectedColor
    @OnChange!

editor.Autosave = () =>
    timer.Remove "TheMP Editor Autosave"

    snapshot = @Serialize!
    metadata = {
        openedFileName: @__openedFileName
        openedPath: @__openedPath
        hasChanged: @__hasChanged
    }

    file.CreateDir "moonpanel_meta"
    file.Write "moonpanel_meta/autosave.txt", util.TableToJSON snapshot
    file.Write "moonpanel_meta/metadata.txt", util.TableToJSON metadata

editor.OnChange = () =>
    if not @__hasChanged
        @SetTitle @GetTitle! .. " (*)"

    @__hasChanged = true

    timer.Remove "TheMP Editor Autosave"
    timer.Create "TheMP Editor Autosave", 5, 1, () ->
        @Autosave!

editor.PerformLayout = (w, h) =>
    @BaseClass.PerformLayout @, w, h
    if @middlePanel
        px, py = @middlePanel\GetPos!

        @upperBar\SetPos px, 0
        @upperBar\SizeToContents!

        titleLabel = nil
        for k, v in pairs @GetChildren!
            if v\GetName! == "DLabel"
                titleLabel = v
                break
 
        if titleLabel
            if not @treePanel\IsVisible!
                tx, ty = titleLabel\GetPos!
                if not titleLabel.initialPos
                    titleLabel.initialPos = { x: tx, y: ty }

                offsety = ty
                offsetx = 8 + @upperBar\GetWide!
            
                bx, by = @upperBar\GetPos!

                titleLabel\SetPos bx + offsetx, by + offsety
            elseif titleLabel.initialPos
                titleLabel\SetPos titleLabel.initialPos.x, titleLabel.initialPos.y

editor.Init = () =>
    __editor = @

    with @
        \SetSize 1100, 700
        \SetTitle "The Moonpanel Editor"
        \SetSizable true
        \SetDraggable true
        \SetDeleteOnClose false
        \Center!
        \Hide!

    @treePanel = vgui.Create "DPanel", @
    with @treePanel
        \Dock LEFT
        \SetWide 250
        \DockMargin 0, 0, 4, 0

    updatebtn = vgui.Create "Button", @treePanel
    with updatebtn
        \Dock BOTTOM
        \SetTall 24
        \SetText "Update"
        .DoClick = () ->
            @UpdateTree!

    @tree = vgui.Create "DTree", @treePanel
    with @tree
        \Dock FILL
        .DoRightClick = (_self, node) ->
            fileName = node.GetFileName and node\GetFileName!
            isFolder = node\GetFolder!

            menu = DermaMenu!

            if not isFolder
                open = menu\AddOption( "Open" )
                open.DoClick = () ->
                    @OpenFile fileName

                menu\AddSpacer!

                saveTo = menu\AddOption "Save into..."
                saveTo.DoClick = () ->
                    Derma_Query "Overwrite file?", "Overwrite",
                        "Yes", () ->
                            @SaveTo fileName
                            @tree\SetSelectedItem node,
                        "No"

                copyTo = menu\AddOption "Copy to..."
                copyTo.DoClick = () ->
                    oldName = node\GetFolder! or node\GetFileName!
                    path = oldName

                    displayName = string.GetFileFromFilename oldName
                    if not isFolder
                        path = string.GetPathFromFilename string.StripExtension oldName
                        displayName = string.StripExtension displayName
                        
                    Derma_StringRequest "Copy To",
                        "Enter the new filename (relative to moonpanel):",
                        displayName,
                        (name) ->        
                            bad = { '\\', '%?', '%%', '%*', ':', '|', '"', '<', '>', '%.', ' ', '"' }

                            if not name or #name == 0
                                return

                            for k, v in pairs(bad) do
                                name = string.gsub name, v, "_"

                            contents = file.Read oldName, "DATA"
                            file.Write "moonpanel/#{name}.txt", contents

                            @UpdateTree!

                delete = menu\AddOption "Delete"
                delete.DoClick = () ->
                    Derma_Query "Are you sure you want to delete #{prettifyFileName fileName}?", "Delete",
                        "Yes", () ->
                            file.Delete fileName
                            @UpdateTree!,
                        "No"

                menu\AddSpacer!
                
            else
                newFolder = menu\AddOption "New Folder..."
                newFolder.DoClick = () ->
                    path = node\GetFolder!

                    Derma_StringRequest "New Folder",
                        "Enter the folder name (relative to #{path}):",
                        "",
                        (name) ->
                            bad = { '\\', '%?', '%%', '%*', ':', '|', '"', '<', '>', '%.', ' ', '"' }

                            if not name or #name == 0
                                return

                            for k, v in pairs(bad) do
                                name = string.gsub name, v, "_"

                            file.CreateDir path .. "/" .. name

                            @UpdateTree!

            if not node.isRoot
                rename = menu\AddOption "Rename..."
                rename.DoClick = () ->
                    oldName = node\GetFolder! or node\GetFileName!
                    path = oldName

                    displayName = string.GetFileFromFilename oldName
                    if not isFolder
                        path = string.GetPathFromFilename string.StripExtension oldName
                        displayName = string.StripExtension displayName
                        
                    Derma_StringRequest "Rename",
                        "Enter the new name:",
                        displayName,
                        (name) ->        
                            bad = { '\\', '%?', '%%', '%*', ':', '|', '"', '<', '>', '%.', ' ', '"' }

                            if not name or #name == 0
                                return

                            for k, v in pairs(bad) do
                                name = string.gsub name, v, "_"

                            file.Rename oldName, "#{path}/#{name}.txt"

                            @UpdateTree!

            menu\Open!

        .DoClick = (_self, node) ->
            if _self.lastNode ~= node
                _self.nextClick = 0

            if _self.lastNode == node and CurTime! <= (_self.nextClick or 0) then
                fileName = node.GetFileName and node\GetFileName!
                if fileName and #fileName > 0
                    @OpenFile fileName

            _self.nextClick = CurTime! + 0.5
            _self.lastNode = node

    @middlePanel = vgui.Create "DPanel", @
    with @middlePanel
        \Dock LEFT
        \SetWide 260
        \DockMargin 0, 0, 0, 0
        .Paint = nil

    @upperBar = vgui.Create "DPanel", @
    @upperBar\SetZPos 1
    @upperBar.Paint = nil

    contractExpand = vgui.Create "DImageButton", @upperBar
    with contractExpand
        \DockMargin 4, 4, 0, 4
        \SetImage "icon16/application_side_contract.png"
        \Dock LEFT
        \SetTooltip "Collapse the File Browser"
        \SizeToContents!
        .DoClick = (_self) ->
            _self.hidden = not _self.hidden
            if _self.hidden
                _self\SetImage "icon16/application_side_contract.png"
                @treePanel\Hide!
            else
                _self\SetImage "icon16/application_side_expand.png"
                @treePanel\Show!
            
            @InvalidateLayout!

    newBtn = vgui.Create "DImageButton", @upperBar
    with newBtn 
        \DockMargin 16, 4, 0, 4
        \SetImage "icon16/page.png"
        \SetTooltip "New"
        \Dock LEFT
        \SizeToContents!
        .DoClick = () ->
            if @__hasChanged
                Derma_Query "You have unsaved changes! Clear anyway?", "New",
                    "Yes", () ->
                        @SetOpenedFile!
                        @Deserialize {},
                    "No"
            else
                @SetOpenedFile!
                @Deserialize {}

    saveBtn = vgui.Create "DImageButton", @upperBar
    with saveBtn
        \DockMargin 4, 4, 0, 4
        \SetImage "icon16/disk.png"
        \Dock LEFT
        \SetTooltip "Save"
        \SizeToContents!
        .DoClick = () ->
            if @__openedFileName
                shouldRefresh = not file.Exists(@__openedFileName, @__openedPath)
                @SaveTo @__openedFileName

                if shouldRefresh
                    @UpdateTree!
            else
                @ShowSaveAsDialog!  

    saveAllBtn = vgui.Create "DImageButton", @upperBar
    with saveAllBtn
        \DockMargin 4, 4, 0, 4
        \SetImage "icon16/disk_multiple.png"
        \Dock LEFT
        \SetTooltip "Save As..."
        \SizeToContents!
        .DoClick = () ->
            @ShowSaveAsDialog!           
    
    @upperBar\SetWide 90
    @upperBar\InvalidateLayout!

    sheet = vgui.Create "DPropertySheet", @middlePanel
    sheet\Dock FILL

    controlsPanel = vgui.Create "DScrollPanel", sheet
    with controlsPanel
        \Dock FILL
        \DockMargin 6, 0, 6, 6

    sheet\AddSheet "Panel", controlsPanel, "icon16/pencil.png"

    --
    -- Controls
    --

    widthHeight = vgui.Create "DPanel", controlsPanel
    widthHeight\Dock TOP
    widthHeight\SetTall 120
    widthHeight.Paint = nil
    
    left = vgui.Create "DPanel", widthHeight
    left\Dock LEFT
    left.Paint = nil
    
    right = vgui.Create "DPanel", widthHeight
    right\Dock RIGHT
    right.Paint = nil

    widthHeight.PerformLayout = (_, w, h) ->
        left\SetWide w/2
        right\SetWide w/2

    label = vgui.Create "DLabel", left
    with label
        \DockMargin 5, 0, 5, 2
        \SetColor Color 0, 0, 0, 255
        \Dock TOP
        \SetText "Width:"

    @widthCombo = vgui.Create "DComboBox", left
    with @widthCombo
        \SetSortItems false
        \DockMargin 5, 0, 5, 2
        \Dock TOP
        \SetValue 3
        .OnSelect = (_, index, value) ->
            data = @Serialize!
            data.Tile.Width = value
            @Deserialize data
            @OnChange!

    for i = 1, 10
        @widthCombo\AddChoice i

    label = vgui.Create "DLabel", right
    with label
        \SetColor Color 0, 0, 0, 255
        \DockMargin 5, 0, 5, 2
        \Dock TOP
        \SetText "Height:"

    @heightCombo = vgui.Create "DComboBox", right
    with @heightCombo
        \SetSortItems false
        \DockMargin 5, 0, 5, 2
        \Dock TOP
        \SetValue 3
        .OnSelect = (_, index, value) ->
            data = @Serialize!
            data.Tile.Height = value
            @Deserialize data
            @OnChange!

    for i = 1, 10
        @heightCombo\AddChoice i

    left\SizeToContents true, true
    right\SizeToContents true, true
    widthHeight\SizeToChildren true, true
    widthHeight\SetTall widthHeight\GetTall! + 20

    widthHeight\InvalidateChildren!
    widthHeight\InvalidateLayout!
 
    @barWidth = vgui.CreateFromTable (include "moonpanel/editor/vgui_circlyslider.lua"), controlsPanel
    with @barWidth
        \DockMargin 5, 8, 5, 2
        \Dock TOP
        \SetText "Bar Width"
        \SetMin 2
        \SetMax 8
        \GetChildren![3]\SetTextColor Color 0, 0, 0
        \GetTextArea!\SetTextColor Color 0, 0, 0
        \GetTextArea!\SetEditable false
        .OnValueChanged = (val) =>
            numval = nil
            val = if val <= @GetMin!
                "Auto"
            else
                numval = val / 100
                val = (math.floor val) .. "%"
                
            @GetTextArea!\SetText val

            if __editor.data
                __editor.data.barWidth = numval
                __editor.grid\InvalidateLayout!
                __editor\OnChange!

        \SetValue 0

    @innerScreenRatio = vgui.CreateFromTable (include "moonpanel/editor/vgui_circlyslider.lua"), controlsPanel
    with @innerScreenRatio
        \DockMargin 5, 0, 5, 2
        \Dock TOP
        \SetValue 0
        \SetText "Inner Ratio"
        \SetMin 0
        \SetMax 100
        \GetChildren![3]\SetTextColor Color 0, 0, 0
        \GetTextArea!\SetTextColor Color 0, 0, 0
        \GetTextArea!\SetText "Auto"
        \GetTextArea!\SetEditable false
        .OnValueChanged = (val) =>
            numval = nil
            val = if val == 0
                "Auto"
            else
                numval = val / 100
                val = (math.floor val) .. "%"

            @GetTextArea!\SetText val

            if __editor.data
                __editor.data.innerScreenRatio = numval
                __editor.grid\InvalidateLayout!
                __editor\OnChange!

    @maxBarLength = vgui.CreateFromTable (include "moonpanel/editor/vgui_circlyslider.lua"), controlsPanel
    with @maxBarLength
        \DockMargin 5, 0, 5, 2
        \Dock TOP
        \SetText "Max Bar Length"
        \SetMin 0
        \SetMax 100
        \GetChildren![3]\SetTextColor Color 0, 0, 0
        \GetTextArea!\SetTextColor Color 0, 0, 0
        \GetTextArea!\SetEditable false
        .OnValueChanged = (val) =>
            numval = nil
            val = if val == 0
                "Auto"
            else
                numval = val / 100
                val = (math.floor val) .. "%"

            @GetTextArea!\SetText val

            if __editor.data
                __editor.data.maxBarLength = numval
                __editor.grid\InvalidateLayout!
                __editor\OnChange!

        \SetValue 0

    @disjointLength = vgui.CreateFromTable (include "moonpanel/editor/vgui_circlyslider.lua"), controlsPanel
    with @disjointLength
        \DockMargin 5, 0, 5, 2
        \Dock TOP
        \SetText "Disjoint Length"
        \SetMin 10
        \SetMax 100
        \GetChildren![3]\SetTextColor Color 0, 0, 0
        \GetTextArea!\SetTextColor Color 0, 0, 0
        \GetTextArea!\SetEditable false
        .OnValueChanged = (val) =>
            numval = nil
            val = if val == 10
                "Auto"
            else
                numval = val / 100
                val = (math.floor val) .. "%"

            @GetTextArea!\SetText val

            if __editor.data
                __editor.data.disjointLength = numval
                __editor.grid\InvalidateLayout!
                __editor\OnChange!

        \SetValue 0

    iconWidth = 50
    unsel = Color 160, 160, 160, 128
    sel = Color 30, 225, 30, 128

    label = vgui.Create "DLabel", controlsPanel
    with label
        \SetColor Color 0, 0, 0, 255
        \DockMargin 5, 8, 5, 2
        \Dock TOP
        \SetText "Color:"

    colorLayout = vgui.Create "DIconLayout", controlsPanel
    __colors = {}
    for i, v in pairs MOONPANEL_COLORS
        button = vgui.Create "DButton", colorLayout
        __colors[#__colors + 1] = button
        with button
            \SetText ""
            \SetWide iconWidth
            \SetTall iconWidth
            \SetTooltip v.tooltip
            .DoClick = (_self) ->
                @selectedColor = i
                _self.selected = true
                for _, btn in pairs __colors
                    if btn ~= _self
                        btn.selected = false

            .Paint = (_self, w, h) ->
                draw.RoundedBox 8, 0, 0, w, h, (_self.selected and sel or unsel)

                innerw = w * 0.6
                innerh = h * 0.6
                draw.RoundedBox 8, (w/2) - (innerw/2), (h/2) - (innerh/2), innerw, innerh, MOONPANEL_COLORS[i]
            if i == 1
                \DoClick!

    with colorLayout
        \DockMargin 5, 0, 5, 0
        \Dock TOP
        \SetSpaceX 4
        \SetSpaceY 4

    label = vgui.Create "DLabel", controlsPanel
    with label
        \SetColor Color 0, 0, 0, 255
        \DockMargin 5, 8, 5, 2
        \Dock TOP
        \SetText "Cell:"

    toolLayout = vgui.Create "DIconLayout", controlsPanel

    @__editorEnts = {}
    __editorEnts = @__editorEnts

    for i, v in pairs editorEnts
        button = vgui.Create "DButton", toolLayout
        button.tool = v
        __editorEnts[#__editorEnts + 1] = button
        with button
            \SetText ""
            \SetWide iconWidth
            \SetTall iconWidth
            \SetTooltip v.tooltip
            .DoClick = () =>
                wasSelected = @selected

                @selected = true
                for _, btn in pairs __editorEnts
                    if btn ~= @
                        btn.selected = false

                if v.click
                    v.click @, wasSelected

            .Paint = (_self, w, h) ->
                draw.RoundedBox 8, 0, 0, w, h, (_self.selected and sel or unsel)
                color = MOONPANEL_COLORS[@selectedColor] or white 
                v.render w, h, color, _self
            if i == 1
                \DoClick!

    with toolLayout
        \DockMargin 5, 0, 5, 2
        \Dock TOP
        \SetSpaceX 4
        \SetSpaceY 4

    label = vgui.Create "DLabel", controlsPanel
    with label
        \SetColor Color 0, 0, 0, 255
        \DockMargin 5, 8, 5, 2
        \Dock TOP
        \SetText "Path / Intersection:"

    pathEntLayout = vgui.Create "DIconLayout", controlsPanel

    @__editorPathEnts = {}
    __editorPathEnts = @__editorPathEnts

    for i, v in pairs editorPathEnts
        button = vgui.Create "DButton", pathEntLayout
        button.tool = v
        __editorPathEnts[#__editorPathEnts + 1] = button
        with button
            \SetText ""
            \SetWide iconWidth
            \SetTall iconWidth
            \SetTooltip v.tooltip
            .DoClick = () =>
                wasSelected = @selected

                @selected = true
                for _, btn in pairs __editorPathEnts
                    if btn ~= @
                        btn.selected = false

                if v.click
                    v.click @, wasSelected

            .Paint = (_self, w, h) ->
                draw.RoundedBox 8, 0, 0, w, h, (_self.selected and sel or unsel)
                color = (@data and @data.colors and @data.colors.untraced) or white
                v.render w, h, color, _self

            if i == 1
                \DoClick!

    with pathEntLayout
        \DockMargin 5, 0, 5, 2
        \Dock TOP
        \SetSpaceX 4
        \SetSpaceY 4

    -------------
    -- Palette --
    -------------

    palettePanel = vgui.Create "DScrollPanel", sheet
    palettePanel\Dock FILL
    palettePanel\DockMargin 6, 0, 6, 6

    sheet\AddSheet "Colors", palettePanel, "icon16/palette.png"

    label = vgui.Create "DLabel", palettePanel
    with label
        \DockMargin 5, 0, 5, 2
        \SetColor Color 0, 0, 0, 255
        \Dock TOP
        \SetText "Presets:"

    combo = vgui.Create "DComboBox", palettePanel
    with combo
        \SetSortItems false
        \DockMargin 5, 0, 5, 2
        \Dock TOP
        \SetValue "Default"

    @data = {
        w: 3
        h: 3
        colors: {

        }
    }

    @grid = vgui.CreateFromTable (include "moonpanel/editor/vgui_panel.lua"), @
    with @grid
        \Dock FILL
    
    if file.Exists "moonpanel_meta/autosave.txt", "DATA"
        @OpenFile "moonpanel_meta/autosave.txt", "DATA", true

        if file.Exists "moonpanel_meta/metadata.txt", "DATA"
            metadata = util.JSONToTable file.Read "moonpanel_meta/metadata.txt", "DATA"
            @SetOpenedFile metadata.openedFileName, metadata.openedPath or "DATA"
            if metadata.hasChanged
                @OnChange! 
    
    else  
        @SetupGrid @data

    @UpdateTree!

editor.SetupGrid = (data) =>
    @grid\Setup @data, (...) ->
        @clickCallback ...

editor.Serialize = () =>
    data_colors = @data.colors or {}

    outputData = {
        Tile: {
            Title: @data.title
            Width: @data.w
            Height: @data.h
        }
        Dimensions: {
            BarWidth: @data.barWidth
            InnerScreenRatio: @data.innerScreenRatio
            MaxBarLength: @data.maxBarLength
            DisjointLength: @data.disjointLength
        }
        Colors: {
            Untraced: data_colors.untraced
            Traced: data_colors.traced
            Finished: data_colors.finished
            Errored: data_colors.errored
            Background: data_colors.background
            Cell: data_colors.cell
        }
        Cells: {}
        Intersections: {}
        VPaths: {}
        HPaths: {}
    }

    for j, row in pairs @grid.rows
        for i, element in pairs row\GetChildren!
            t = nil
            if not element.entity
                continue

            if j % 2 == 0
                if i % 2 == 0
                    x, y = i / 2, j / 2

                    outputData.Cells[y] or= {}
                    outputData.Cells[y][x] = {}
                    t = outputData.Cells[y][x]
                    
                else
                    x, y = math.floor(i / 2) + 1, j / 2

                    outputData.VPaths[y] or= {}
                    outputData.VPaths[y][x] = {}
                    t = outputData.VPaths[y][x]
                    
            else
                if i % 2 == 0
                    x, y = i / 2, math.floor(j / 2) + 1
                    
                    outputData.HPaths[y] or= {}
                    outputData.HPaths[y][x] = {}
                    t = outputData.HPaths[y][x]
                    
                else
                    x, y = math.floor(i / 2) + 1, math.floor(j / 2) + 1

                    outputData.Intersections[y] or= {}
                    outputData.Intersections[y][x] = {}
                    t = outputData.Intersections[y][x]
            
            if t
                t.Type = element.entity
                t.Attributes = {
                    Color: element.attributes.color
                }
                switch t.Type
                    when MOONPANEL_ENTITY_TYPES.TRIANGLE
                        t.Attributes.Count = element.attributes.count or 1

                    when MOONPANEL_ENTITY_TYPES.POLYOMINO
                        t.Attributes.Shape = {}
                        for j = 1, element.attributes.shape.h
                            t.Attributes.Shape[j] = {}
                            for i = 1, element.attributes.shape.w
                                t.Attributes.Shape[j][i] = element.attributes.shape[j][i] and 1 or 0
                        
                        t.Attributes.Rotational = element.attributes.shape.rotational

    return outputData

editor.Deserialize = (input) =>
    input_tile = input.Tile or {}
    input_dimensions = input.Dimensions or {}

    newData = {
        title: input_tile.Title
        w: input_tile.Width or 3
        h: input_tile.Height or 3
        
        barWidth: input_dimensions.BarWidth
        innerScreenRatio: input_dimensions.InnerScreenRatio
        maxBarLength: input_dimensions.MaxBarLength
        disjointLength: input_dimensions.DisjointLength

        cells: {}
        intersections: {}
        vpaths: {}
        hpaths: {}
        colors: {}
    }

    @barWidth\SetValue newData.barWidth
    @innerScreenRatio\SetValue newData.innerScreenRatio
    @maxBarLength\SetValue newData.maxBarLength
    @disjointLength\SetValue newData.disjointLength

    @widthCombo\SetText newData.w
    @heightCombo\SetText newData.h

    w, h = newData.w, newData.h
    for j = 1, h + 1
        for i = 1, w + 1
            si, sj = i, j

            if input.Cells and j <= h and i <= w and input.Cells[sj] and input.Cells[sj][si]
                cell = input.Cells[sj][si]
                atts = cell.Attributes or {}

                newData.cells[sj] or= {}
                newData.cells[sj][si] = {
                    entity: cell.Type
                    attributes: {
                        color: atts.Color or 1
                        count: atts.Count
                    }
                }

                newAtts = newData.cells[sj][si].attributes

                if atts.Shape
                    maxlen = nil 
                    for _j, row in pairs atts.Shape
                        if not maxlen or #row > maxlen
                            maxlen = #row

                    newAtts.shape = {
                        w: maxlen
                        h: #atts.Shape
                    }
                    newAtts.shape.rotational = atts.Rotational

                    for _j, row in pairs atts.Shape
                        newAtts.shape[_j] = {}
                        for _i = 1, maxlen
                            newAtts.shape[_j][_i] = (row[_i] == 1) and true or false

            if input.HPaths and i <= w and input.HPaths[sj] and input.HPaths[sj][si]
                hbar = input.HPaths[sj][si]

                newData.hpaths[sj] or= {}
                newData.hpaths[sj][si] = {
                    entity: hbar.Type
                }

            if input.VPaths and j <= h and input.VPaths[sj] and input.VPaths[sj][si]
                vbar = input.VPaths[sj][si]

                newData.vpaths[sj] or= {}
                newData.vpaths[sj][si] = {
                    entity: vbar.Type
                }

            if input.Intersections and input.Intersections[sj] and input.Intersections[sj][si]
                int = input.Intersections[sj][si]

                newData.intersections[sj] or= {}
                newData.intersections[sj][si] = {
                    entity: int.Type
                }
    
    table.Empty @data
    table.CopyFromTo newData, @data

    @SetupGrid @data

editor.SetOpenedFile = (fileName, path = "DATA") =>
    @__openedFileName = fileName
    @__openedPath = path
    @__hasChanged = false

    @SetTitle if fileName
        pretty = prettifyFileName(fileName or "")
        "The Moonpanel Editor - #{pretty}"
    else
        "The Moonpanel Editor"

editor.OpenFile = (fileName, path = "DATA", silent) =>
    open = () ->
        if not IsValid @
            return

        contents = (file.Read fileName, path) or "{}"
        contents = util.JSONToTable contents

        if contents
            @Deserialize contents
            @SetOpenedFile fileName
        elseif not silent
            Derma_Message "Couldn't open \"#{prettifyFileName fileName}\": invalid format", "Error"

    if not silent and @__hasChanged
        Derma_Query "You have unsaved changes! Open anyway?", "Open File",
            "Yes", () ->
                open!,
            "No"
    else
        open!

editor.SaveTo = (fileName) =>
    fileName = "moonpanel/#{prettifyFileName(fileName)}.txt"
    path = string.GetPathFromFilename fileName

    file.CreateDir path
    file.Write fileName, util.TableToJSON @Serialize!, true

    @SetOpenedFile fileName

    notification.AddLegacy "Saved to #{prettifyFileName(fileName)}", NOTIFY_GENERIC, 5
    surface.PlaySound "ambient/water/drip3.wav"
    
editor.ShowSaveAsDialog = () =>
    Derma_StringRequest "Save As",
        "Enter the filename:",
        prettifyFileName(@__openedFileName or ""),
        (fileName) ->
            bad = { '\\', '%?', '%%', '%*', ':', '|', '"', '<', '>', '%.', ' ', '"' }

            if not fileName or #fileName == 0
                return

            for k, v in pairs(bad) do
                fileName = string.gsub fileName, v, "_"

            @SaveTo fileName
            @UpdateTree!  

editor.OnClose = () =>
    @Autosave!

editor.OnRemove = () =>
    @Autosave!

return vgui.RegisterTable editor, "DFrame"