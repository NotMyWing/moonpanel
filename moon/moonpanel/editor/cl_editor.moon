editor = {}

TIPLABEL_TIPS = {
    "You can remove an entity by clicking on it twice!"
    "You can copy an entity by right-clicking on it!"
    "The editor autosaves your puzzles. Don't worry about accidentally losing your progress!"
    "You should play The Witness!"
}

-----------------------------------
--                               --
-- HERE BE LOCALS.               --
--                               --
-----------------------------------

prettifyFileName = (fileName) ->
    s, e = string.find fileName, "/"
    if s
        fileName = string.sub fileName, e + 1, -1

    return string.StripExtension fileName

normalizePolyomino = (t) ->
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
    if (a.rotational or false) ~= (b.rotational or false)
        return false

    if a.w ~= b.w or a.h ~= b.h
        return false

    for i = 1, a.h
        for j = 1, a.w
            if a[j] and b[j] and (a[j][i] ~= b[j][i])
                return false
    
    return true

POLYOMINO_EDITOR = nil
POLYOMINO_EDITOR_DATA = {}

COLOR_WHITE = Color 255, 255, 255

-----------------------------------
--                               --
-- HERE BE TOOLSETS.             --
--                               --
-----------------------------------

TOOL_GRAPHICS = {
    ["place"]: (Material "moonpanel/editor_brush.png", "noclamp smooth")
    ["erase"]: (Material "moonpanel/editor_eraser.png", "noclamp smooth")
    ["flood"]: (Material "moonpanel/editor_bucket.png", "noclamp smooth")
}

ENTITY_GRAPHICS = {
    [Moonpanel.EntityTypes.Polyomino]: (Material "moonpanel/polyo.png", "noclamp smooth")
    [Moonpanel.EntityTypes.Sun]: (Material "moonpanel/sun.png", "noclamp smooth")
    [Moonpanel.EntityTypes.Triangle]: (Material "moonpanel/triangle.png", "noclamp smooth")
    [Moonpanel.EntityTypes.Color]: (Material "moonpanel/color.png", "noclamp smooth") 
    [Moonpanel.EntityTypes.Eraser]: (Material "moonpanel/eraser.png", "noclamp smooth")
    [Moonpanel.EntityTypes.Start]: (Material "moonpanel/start.png", "noclamp smooth")
    [Moonpanel.EntityTypes.End]: (Material "moonpanel/end.png", "noclamp smooth")
    [Moonpanel.EntityTypes.Disjoint]: (Material "moonpanel/disjoint.png", "noclamp smooth")
    [Moonpanel.EntityTypes.Hexagon]: {
        (Material "moonpanel/hex_layer1.png", "noclamp smooth")
        (Material "moonpanel/hex_layer2.png", "noclamp smooth")
    }
}

TOOLSET_TOOLS = {
    -----------------
    -- Tool: brush --
    -----------------
    {
        tooltip: "Place or Erase Entities"
        render: (w, h) ->
            innerw = w * 0.8
            innerh = h * 0.8

            surface.SetDrawColor COLOR_WHITE
            surface.SetMaterial TOOL_GRAPHICS["place"]
            surface.DrawTexturedRect (w/2) - (innerw/2), (h/2) - (innerh/2), innerw, innerh

        click: (button, gridElement, color) ->
            if button and button.tool and button.tool.set
                button.tool.set button, gridElement, color
                return true
    }
    ------------------
    -- Tool: eraser --
    ------------------
    {
        tooltip: "Erase Entities"
        render: (w, h) ->
            innerw = w * 0.8
            innerh = h * 0.8

            surface.SetDrawColor COLOR_WHITE
            surface.SetMaterial TOOL_GRAPHICS["erase"]
            surface.DrawTexturedRect (w/2) - (innerw/2), (h/2) - (innerh/2), innerw, innerh

        click: (button, gridElement, color) ->
            if gridElement and gridElement.entity
                gridElement.entity = nil
                return true
    }
    -------------------
    -- Tool: recolor --
    -------------------
    {
        tooltip: "Recolor Entities"
        render: (w, h) ->
            innerw = w * 0.8
            innerh = h * 0.8

            surface.SetDrawColor COLOR_WHITE
            surface.SetMaterial TOOL_GRAPHICS["flood"]
            surface.DrawTexturedRect (w/2) - (innerw/2), (h/2) - (innerh/2), innerw, innerh

        click: (button, gridElement, color) ->
            if gridElement and gridElement.entity and gridElement.attributes
                gridElement.attributes.color = color
                return true
    }
}

TOOLSET_ENTITIES = {
    ------------------------
    -- Tool: color entity --
    ------------------------
    {
        tooltip: "Color"
        entity: Moonpanel.EntityTypes.Color
        target: Moonpanel.ObjectTypes.Cell

        render: (w, h, color) ->
            surface.SetDrawColor color
            surface.SetMaterial ENTITY_GRAPHICS[Moonpanel.EntityTypes.Color]
            surface.DrawTexturedRect 0, 0, w, h

        set: (button, gridElement, color) ->
            if gridElement.attributes.color == color and gridElement.entity == Moonpanel.EntityTypes.Color
                gridElement.entity = nil
            else
                gridElement.attributes.color = color
                gridElement.entity = Moonpanel.EntityTypes.Color 
    }
    ------------------------
    -- Tool: sun entity   --
    ------------------------
    {
        tooltip: "Sun / Star"
        entity: Moonpanel.EntityTypes.Sun
        target: Moonpanel.ObjectTypes.Cell

        render: (w, h, color) ->
            surface.SetDrawColor color
            surface.SetMaterial ENTITY_GRAPHICS[Moonpanel.EntityTypes.Sun]
            surface.DrawTexturedRect 0, 0, w, h

        set: (button, gridElement, color) ->
            if gridElement.attributes.color == color and gridElement.entity == Moonpanel.EntityTypes.Sun
                gridElement.entity = nil

            else
                gridElement.attributes.color = color
                gridElement.entity = Moonpanel.EntityTypes.Sun 
    }
    -------------------------
    -- Tool: eraser entity --
    -------------------------
    {
        tooltip: "Y-Symbol / Eraser"
        entity: Moonpanel.EntityTypes.Eraser
        target: Moonpanel.ObjectTypes.Cell

        render: (w, h, color) ->
            surface.SetDrawColor color
            surface.SetMaterial ENTITY_GRAPHICS[Moonpanel.EntityTypes.Eraser]
            surface.DrawTexturedRect 0, 0, w, h

        set: (button, gridElement, color) ->
            if gridElement.attributes.color == color and gridElement.entity == Moonpanel.EntityTypes.Eraser
                gridElement.entity = nil
            else
                gridElement.attributes.color = color
                gridElement.entity = Moonpanel.EntityTypes.Eraser 
    }
    ------------------------
    -- Tool: polyo entity --
    ------------------------
    {
        tooltip: "Polyomino / Tetris"
        entity: Moonpanel.EntityTypes.Polyomino
        target: Moonpanel.ObjectTypes.Cell

        copy: (button, editor, gridElement) ->
            table.Empty POLYOMINO_EDITOR_DATA
            table.CopyFromTo gridElement.attributes.shape, POLYOMINO_EDITOR_DATA

        render: (w, h, color) ->
            surface.SetDrawColor color
            surface.SetMaterial ENTITY_GRAPHICS[Moonpanel.EntityTypes.Polyomino]
            surface.DrawTexturedRect 0, 0, w, h

        click: (button, wasSelected) ->
            if IsValid button.POLYOMINO_EDITOR
                button.POLYOMINO_EDITOR\Remove!

            button.POLYOMINO_EDITOR = vgui.CreateFromTable (include "moonpanel/editor/vgui_polyoeditor.lua")

            if IsValid button.POLYOMINO_EDITOR
                x, y = button\LocalToScreen 0, button\GetTall!
                POLYOMINO_EDITOR = button.POLYOMINO_EDITOR
                with POLYOMINO_EDITOR
                    \Setup POLYOMINO_EDITOR_DATA
                    \MakePopup!
                    \Show!
                    \SetPos x, y
                    \RequestFocus!
                    timer.Simple 0.01, () ->
                        .Think = () ->
                            if not \HasFocus!
                                \Remove!

        set: (button, gridElement, color) ->
            norm = normalizePolyomino POLYOMINO_EDITOR_DATA

            if not norm or 
                (gridElement.attributes.color == color and 
                    gridElement.entity == Moonpanel.EntityTypes.Polyomino and
                    gridElement.attributes.shape and
                    (comparePolyos norm, gridElement.attributes.shape)
                )
                gridElement.entity = nil
            elseif norm
                gridElement.attributes.color = color

                gridElement.attributes.shape = norm
                gridElement.entity = Moonpanel.EntityTypes.Polyomino 
    }
    ---------------------------
    -- Tool: triangle entity --
    ---------------------------
    {
        tooltip: "Triangle (Click again to change the count)"
        entity: Moonpanel.EntityTypes.Triangle
        target: Moonpanel.ObjectTypes.Cell

        copy: (button, editor, gridElement) ->
            button.count = gridElement.attributes.count

        render: (w, h, color, button) ->
            button.count or= 1
            surface.SetDrawColor color
            surface.SetMaterial ENTITY_GRAPHICS[Moonpanel.EntityTypes.Triangle]
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
            button.count or= 1
            if wasSelected
                button.count = (button.count % 3) + 1

        set: (button, gridElement, color) ->
            count = button.count
            if gridElement.attributes.color == color and 
                gridElement.attributes.count == count and gridElement.entity == Moonpanel.EntityTypes.Triangle
                gridElement.entity = nil
            else
                gridElement.attributes.color = color
                gridElement.attributes.count = count
                gridElement.entity = Moonpanel.EntityTypes.Triangle 
    }
}

TOOLSET_PATHENTITIES = {
    ------------------------
    -- Tool: start entity --
    ------------------------
    {
        tooltip: "Entrance / Start"
        entity: Moonpanel.EntityTypes.Start
        target: Moonpanel.ObjectTypes.Intersection

        render: (w, h, color) ->
            surface.SetDrawColor color
            surface.SetMaterial ENTITY_GRAPHICS[Moonpanel.EntityTypes.Start]
            surface.DrawTexturedRect 0, 0, w, h

        set: (button, gridElement, color) ->
            if gridElement.entity == Moonpanel.EntityTypes.Start
                gridElement.entity = nil
            else
                gridElement.entity = Moonpanel.EntityTypes.Start 
    }
    -----------------------
    -- Tool: exit entity --
    -----------------------
    {
        tooltip: "Exit / End"
        entity: Moonpanel.EntityTypes.End
        target: Moonpanel.ObjectTypes.Intersection

        render: (w, h, color) ->
            surface.SetDrawColor color
            surface.SetMaterial ENTITY_GRAPHICS[Moonpanel.EntityTypes.End]
            surface.DrawTexturedRect 0, 0, w, h

        set: (button, gridElement, color) ->
            if gridElement.entity == Moonpanel.EntityTypes.End
                gridElement.entity = nil
            else
                gridElement.entity = Moonpanel.EntityTypes.End 
    }
    ---------------------------
    -- Tool: disjoint entity --
    ---------------------------
    {
        tooltip: "Break / Disjoint"
        entity: Moonpanel.EntityTypes.Disjoint
        target: { Moonpanel.ObjectTypes.HPath, Moonpanel.ObjectTypes.VPath }

        render: (w, h, color) ->
            surface.SetDrawColor color
            surface.SetMaterial ENTITY_GRAPHICS[Moonpanel.EntityTypes.Disjoint]
            surface.DrawTexturedRect 0, 0, w, h

        set: (button, gridElement, color) ->
            if gridElement.entity == Moonpanel.EntityTypes.Disjoint
                gridElement.entity = nil
            else
                gridElement.entity = Moonpanel.EntityTypes.Disjoint 
    }
    --------------------------
    -- Tool: hexagon entity --
    --------------------------
    {
        tooltip: "Dot / Hexagon"
        entity: Moonpanel.EntityTypes.Hexagon
        target: { Moonpanel.ObjectTypes.HPath, Moonpanel.ObjectTypes.VPath, Moonpanel.ObjectTypes.Intersection }

        render: (w, h, bgColor, entColor) ->
            surface.SetDrawColor bgColor
            surface.SetMaterial ENTITY_GRAPHICS[Moonpanel.EntityTypes.Hexagon][1]
            surface.DrawTexturedRect 0, 0, w, h
            surface.SetDrawColor entColor
            surface.SetMaterial ENTITY_GRAPHICS[Moonpanel.EntityTypes.Hexagon][2]
            surface.DrawTexturedRect 0, 0, w, h

        set: (button, gridElement, color) ->
            if gridElement.attributes.color == color and gridElement.entity == Moonpanel.EntityTypes.Hexagon
                gridElement.entity = nil
            else
                gridElement.attributes.color = color
                gridElement.entity = Moonpanel.EntityTypes.Hexagon 
    }
}

-----------------------------------
--                               --
-- HERE BE THE EDITOR.           --
--                               --
-----------------------------------

editor.UpdateTree = () =>
    @tree_fileTree\Clear!

    node = @tree_fileTree\AddNode "moonpanel"
    node\MakeFolder "moonpanel", "DATA", true
    node\SetExpanded true
    node.isRoot = true

editor.Grid_ClickCallback = (element) =>
    if not element
        return

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

    for k, v in pairs @__toolset_entities
        val = fn v
        if val
            selected = val
            break

    if not selected 
        for k, v in pairs @__toolset_path_entities
            val = fn v
            if val
                selected = val
                break
    
    if not selected
        return

    button = nil
    for k, v in pairs @__toolset_tools
        if v.selected
            button = v

    if not button
        return

    element.attributes or= {}
    if button.tool.click selected, element, @selectedColor
        @OnChange!

editor.Grid_CopyCallback = (element) =>
    button = nil

    fn = (btn) ->
        if btn.tool.entity == element.entity
            return btn

    for k, v in pairs @__toolset_entities
        val = fn v
        if val
            button = val
            break

    if not button 
        for k, v in pairs @__toolset_path_entities
            val = fn v
            if val
                button = val
                break
 
    if not button
        return

    element.attributes or= {}
    colorButton = nil
    for k, v in pairs @__toolset_colors
        if v.color == (element.attributes.color or Moonpanel.Color.Black)
            colorButton = v
            break

    if button
        button\Select!

        if button.tool.copy
            button.tool.copy button, editor, element

    if colorButton
        colorButton\DoClick!

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
    timer.Create "TheMP Editor Autosave", 1, 1, () ->
        @Autosave!

editor.PerformLayout = (w, h) =>
    @BaseClass.PerformLayout @, w, h
    if @panel_middleContainer
        px, py = @panel_middleContainer\GetPos!

        @panel_toolBar\SetPos px, 0
        @panel_toolBar\SizeToContents!
        @label_tips\SizeToContents!

        titleLabel = nil
        for k, v in pairs @GetChildren!
            if v\GetName! == "DLabel"
                titleLabel = v
                break
 
        if titleLabel
            if not @panel_fileTreeContainer\IsVisible!
                tx, ty = titleLabel\GetPos!
                if not titleLabel.initialPos
                    titleLabel.initialPos = { x: tx, y: ty }

                offsety = ty
                offsetx = 8 + @panel_toolBar\GetWide!
            
                bx, by = @panel_toolBar\GetPos!

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

    @panel_fileTreeContainer = with vgui.Create "DPanel", @
        \Dock LEFT
        \SetWide 250
        \DockMargin 0, 0, 4, 0

    with vgui.Create "Button", @panel_fileTreeContainer
        \Dock BOTTOM
        \SetTall 24
        \SetText "Update"
        .DoClick = () ->
            @UpdateTree!

    @tree_fileTree = with vgui.Create "DTree", @panel_fileTreeContainer
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
                            @tree_fileTree\SetSelectedItem node,
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

    
    @panel_middleContainer = with vgui.Create "DPanel", @
        \Dock LEFT
        \SetWide 305
        \DockMargin 0, 0, 0, 0
        .Paint = nil

    @panel_toolBar = with vgui.Create "DPanel", @
        \SetZPos 1
        .Paint = nil

    with vgui.Create "DImageButton", @panel_toolBar
        \DockMargin 4, 4, 0, 4
        \SetImage "icon16/application_side_contract.png"
        \Dock LEFT
        \SetTooltip "Collapse the File Browser"
        \SizeToContents!
        .DoClick = (_self) ->
            _self.hidden = not _self.hidden
            if _self.hidden
                _self\SetImage "icon16/application_side_contract.png"
                @panel_fileTreeContainer\Hide!
            else
                _self\SetImage "icon16/application_side_expand.png"
                @panel_fileTreeContainer\Show!
            
            @InvalidateLayout!

    with vgui.Create "DImageButton", @panel_toolBar
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

    with vgui.Create "DImageButton", @panel_toolBar
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

    with vgui.Create "DImageButton", @panel_toolBar
        \DockMargin 4, 4, 0, 4
        \SetImage "icon16/disk_multiple.png"
        \Dock LEFT
        \SetTooltip "Save As..."
        \SizeToContents!
        .DoClick = () ->
            @ShowSaveAsDialog!   

    with vgui.Create "DImageButton", @panel_toolBar
        \DockMargin 4, 4, 0, 4
        \SetImage "icon16/cancel.png"
        \Dock LEFT
        \SetTooltip "Clear..."
        \SizeToContents!
        .DoClick = () ->
            Derma_Query "This will remove all entities from the grid! Clear anyway?", "Clear",
                "Yes", () ->
                    data = @Serialize!
                    data.VPaths = {}
                    data.HPaths = {}
                    data.Intersections = {}
                    data.Cells = {}
                    @Deserialize data
                    @OnChange!,
                "No"

    with vgui.Create "DImageButton", @panel_toolBar
        \DockMargin 16, 4, 0, 4
        \SetImage "moonpanel/icon16_windmill.png"
        \Dock LEFT
        \SetTooltip "Import from The Windmill..."
        \SizeToContents!
        .DoClick = () ->
            --@ShowSaveAsDialog!     
    
    @panel_toolBar\SetWide 160
    @panel_toolBar\InvalidateLayout!

    @sheet_toolSheet = with vgui.Create "DPropertySheet", @panel_middleContainer
        \Dock FILL

    panel_controls = with vgui.Create "DScrollPanel", @sheet_toolSheet
        \Dock FILL
        \DockMargin 6, 0, 6, 6

    @sheet_toolSheet\AddSheet "Panel", panel_controls, "icon16/pencil.png"

    do
        widthHeight = with vgui.Create "DPanel", panel_controls
            \Dock TOP
            \SetTall 120
            .Paint = nil

        left = with vgui.Create "DPanel", widthHeight
            \Dock LEFT
            .Paint = nil

        right = with vgui.Create "DPanel", widthHeight
            \Dock RIGHT
            .Paint = nil

        center = with vgui.Create "DPanel", widthHeight
            \Dock FILL
            .Paint = nil

        widthHeight.PerformLayout = (_, w, h) ->
            left\SetWide w/3
            center\SetWide w/3
            right\SetWide w/3

        with vgui.Create "DLabel", left
            \DockMargin 5, 0, 5, 2
            \SetColor Color 0, 0, 0, 255
            \Dock TOP
            \SetText "Width:"

        @comboBox_widthCombo = with vgui.Create "DComboBox", left
            \SetSortItems false
            \DockMargin 5, 0, 5, 2
            \Dock TOP
            \SetValue 3
            .OnSelect = (_, index, value) ->
                data = @Serialize!
                if not data
                    return

                data.Tile.Width = value
                @Deserialize data
                @OnChange!

            for i = 1, 10
                \AddChoice i

        with vgui.Create "DLabel", center
            \SetColor Color 0, 0, 0, 255
            \DockMargin 5, 0, 5, 2
            \Dock TOP
            \SetText "Height:"

        @comboBox_heightCombo = with vgui.Create "DComboBox", center
            \SetSortItems false
            \DockMargin 5, 0, 5, 2
            \Dock TOP
            \SetValue 3
            .OnSelect = (_, index, value) ->
                data = @Serialize!
                if not data
                    return

                data.Tile.Height = value
                @Deserialize data
                @OnChange!

            for i = 1, 10
                \AddChoice i

        with vgui.Create "DLabel", right
            \SetColor Color 0, 0, 0, 255
            \DockMargin 5, 0, 5, 2
            \Dock TOP
            \SetText "Symmetry:"

        @comboBox_symmetryCombo = with vgui.Create "DComboBox", right
            \SetSortItems false
            \DockMargin 5, 0, 5, 2
            \Dock TOP
            \AddChoice "None", 0
            \AddChoice "Horizontal", Moonpanel.Symmetry.Horizontal
            \AddChoice "Vertical", Moonpanel.Symmetry.Vertical
            \AddChoice "Rotational", Moonpanel.Symmetry.Rotational

            \ChooseOptionID 1
            .OnSelect = (_, index, value, d) ->
                data = @Serialize!
                if not data
                    return

                data.Tile.Symmetry = d
                @Deserialize data
                @OnChange!

        left\SizeToContents true, true
        center\SizeToContents true, true
        right\SizeToContents true, true

        with widthHeight
            \SizeToChildren true, true
            \SetTall widthHeight\GetTall! + 20
            \InvalidateChildren!
            \InvalidateLayout!
 
    with @slider_barWidth = vgui.CreateFromTable (include "moonpanel/editor/vgui_circlyslider.lua"), panel_controls
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
                __editor.moonpanel_grid\InvalidateLayout!
                __editor\OnChange!

        \SetValue 0

    with @slider_innerScreenRatio = vgui.CreateFromTable (include "moonpanel/editor/vgui_circlyslider.lua"), panel_controls
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
                __editor.moonpanel_grid\InvalidateLayout!
                __editor\OnChange!

    with @slider_maxBarLength = vgui.CreateFromTable (include "moonpanel/editor/vgui_circlyslider.lua"), panel_controls
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
                __editor.moonpanel_grid\InvalidateLayout!
                __editor\OnChange!

        \SetValue 0

    with @slider_disjointLength = vgui.CreateFromTable (include "moonpanel/editor/vgui_circlyslider.lua"), panel_controls
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
                __editor.moonpanel_grid\InvalidateLayout!
                __editor\OnChange!

        \SetValue 0

    ICON_WIDTH = 50
    COLOR_TOOL_UNSELECTED = Color 160, 160, 160, 128
    COLOR_TOOL_SELECTED = Color 30, 225, 30, 128

    -----------------------------------
    --                               --
    -- Tools toolset. haha.          --
    --                               --
    -----------------------------------
    do
        @__toolset_tools = {}

        with vgui.Create "DLabel", panel_controls
            \SetColor Color 0, 0, 0, 255
            \DockMargin 5, 8, 5, 2
            \Dock TOP
            \SetText "Tool:"

        toolLayout = with vgui.Create "DIconLayout", panel_controls
            \DockMargin 5, 0, 5, 2
            \Dock TOP
            \SetSpaceX 4
            \SetSpaceY 4

        for i, v in pairs TOOLSET_TOOLS
            button = vgui.Create "DButton", toolLayout
            button.tool = v
            __editor.__toolset_tools[#__editor.__toolset_tools + 1] = button

            with button
                \SetText ""
                \SetWide ICON_WIDTH
                \SetTall ICON_WIDTH
                \SetTooltip v.tooltip
                .Select = () =>
                    wasSelected = @selected

                    @selected = true
                    for _, btn in pairs __editor.__toolset_tools
                        if btn ~= @
                            btn.selected = false

                    return wasSelected

                .DoClick = () =>
                    wasSelected = @Select!
                    
                    if v.click
                        v.click @, wasSelected

                .Paint = (_self, w, h) ->
                    draw.RoundedBox 8, 0, 0, w, h, (_self.selected and COLOR_TOOL_SELECTED or COLOR_TOOL_UNSELECTED)
                    color = Moonpanel.Colors[@selectedColor] or COLOR_WHITE 
                    v.render w, h, color, _self

                if i == 1
                    \DoClick!

    -----------------------------------
    --                               --
    -- Colors toolset.               --
    --                               --
    -----------------------------------
    do
        @__toolset_colors = {}
        with vgui.Create "DLabel", panel_controls
            \SetColor Color 0, 0, 0, 255
            \DockMargin 5, 8, 5, 2
            \Dock TOP
            \SetText "Color:"

        colorLayout = with vgui.Create "DIconLayout", panel_controls
            \DockMargin 5, 0, 5, 0
            \Dock TOP
            \SetSpaceX 4
            \SetSpaceY 4

        for i, v in pairs Moonpanel.Colors
            button = vgui.Create "DButton", colorLayout
            button.color = i
            @__toolset_colors[#@__toolset_colors + 1] = button

            with button
                \SetText ""
                \SetWide ICON_WIDTH
                \SetTall ICON_WIDTH
                .DoClick = (_self) ->
                    @selectedColor = i
                    _self.selected = true
                    for _, btn in pairs @__toolset_colors
                        if btn ~= _self
                            btn.selected = false

                .Paint = (_self, w, h) ->
                    draw.RoundedBox 8, 0, 0, w, h, (_self.selected and COLOR_TOOL_SELECTED or COLOR_TOOL_UNSELECTED)

                    innerw = w * 0.6
                    innerh = h * 0.6
                    draw.RoundedBox 8, (w/2) - (innerw/2), (h/2) - (innerh/2), innerw, innerh, v

                if i == 1
                    \DoClick!

    -----------------------------------
    --                               --
    -- Cell entity toolset.          --
    --                               --
    -----------------------------------
    do
        @__toolset_entities = {}

        with vgui.Create "DLabel", panel_controls
            \SetColor Color 0, 0, 0, 255
            \DockMargin 5, 8, 5, 2
            \Dock TOP
            \SetText "Cell:"

        entLayout = with vgui.Create "DIconLayout", panel_controls
            \DockMargin 5, 0, 5, 2
            \Dock TOP
            \SetSpaceX 4
            \SetSpaceY 4

        for i, v in pairs TOOLSET_ENTITIES
            button = vgui.Create "DButton", entLayout
            button.tool = v
            __editor.__toolset_entities[#__editor.__toolset_entities + 1] = button

            with button
                \SetText ""
                \SetWide ICON_WIDTH
                \SetTall ICON_WIDTH
                \SetTooltip v.tooltip
                .Select = () =>
                    wasSelected = @selected

                    @selected = true
                    for _, btn in pairs __editor.__toolset_entities
                        if btn ~= @
                            btn.selected = false

                    return wasSelected

                .DoClick = () =>
                    wasSelected = @Select!
                    
                    if v.click
                        v.click @, wasSelected

                .Paint = (_self, w, h) ->
                    draw.RoundedBox 8, 0, 0, w, h, (_self.selected and COLOR_TOOL_SELECTED or COLOR_TOOL_UNSELECTED)
                    color = Moonpanel.Colors[@selectedColor] or 1 
                    v.render w, h, color, _self
                if i == 1
                    \DoClick!

    -----------------------------------
    --                               --
    -- Path entities toolset.        --
    --                               --
    -----------------------------------
    do
        @__toolset_path_entities = {}

        with vgui.Create "DLabel", panel_controls
            \SetColor Color 0, 0, 0, 255
            \DockMargin 5, 8, 5, 2
            \Dock TOP
            \SetText "Path / Intersection:"

        pathEntLayout = with vgui.Create "DIconLayout", panel_controls
            \DockMargin 5, 0, 5, 2
            \Dock TOP
            \SetSpaceX 4
            \SetSpaceY 4

        for i, v in pairs TOOLSET_PATHENTITIES
            button = vgui.Create "DButton", pathEntLayout
            button.tool = v
            __editor.__toolset_path_entities[#__editor.__toolset_path_entities + 1] = button

            with button
                \SetText ""
                \SetWide ICON_WIDTH
                \SetTall ICON_WIDTH
                \SetTooltip v.tooltip
                .Select = () =>
                    wasSelected = @selected

                    @selected = true
                    for _, btn in pairs __editor.__toolset_path_entities
                        if btn ~= @
                            btn.selected = false

                    return wasSelected

                .DoClick = () =>
                    wasSelected = @Select!
                    
                    if v.click
                        v.click @, wasSelected

                .Paint = (_self, w, h) ->
                    draw.RoundedBox 8, 0, 0, w, h, (_self.selected and COLOR_TOOL_SELECTED or COLOR_TOOL_UNSELECTED)
                    bgColor = (@data and @data.colors and @data.colors.untraced) or Moonpanel.DefaultColors.Untraced
                    bgColor = ColorAlpha bgColor, 128

                    entColor = Moonpanel.Colors[@selectedColor] or 1

                    v.render w, h, bgColor, entColor

                if i == 1
                    \DoClick!

    -----------------------------------
    --                               --
    -- Palette                       --
    --                               --
    -----------------------------------

    panel_palette = with vgui.Create "DScrollPanel", @sheet_toolSheet
        \Dock FILL
        \DockMargin 6, 0, 6, 6

    @sheet_toolSheet\AddSheet "Colors", panel_palette, "icon16/palette.png"

    with vgui.Create "DLabel", panel_palette
        \DockMargin 5, 0, 5, 2
        \SetColor Color 0, 0, 0, 255
        \Dock TOP
        \SetText "Presets:"

    with vgui.Create "DComboBox", panel_palette
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

    panel_gridContainer = with vgui.Create "DPanel", @
        \Dock FILL
        .Paint = nil

    @label_tips = with vgui.Create "DButton", panel_gridContainer
        \Dock BOTTOM
        \SetFont "Trebuchet18"
        \SetMultiline true
        \SetContentAlignment 5
        .Paint = nil
        .DoClick = () =>
            text = nil

            if #TIPLABEL_TIPS >= 1
                @__lastTipID = @__tipID

                while @__tipID == @__lastTipID
                    @__tipID = math.random 1, #TIPLABEL_TIPS
                
                text = TIPLABEL_TIPS[@__tipID]
            else
                text = TIPLABEL_TIPS[1] or "There were once tips."
            
            \SetText "Did you know? " .. text
        \DoClick!
        \SetTextColor Color 255, 255, 255

    @moonpanel_grid = with vgui.CreateFromTable (include "moonpanel/editor/vgui_panel.lua"), panel_gridContainer
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
    click = (...) ->
        @Grid_ClickCallback ...

    copy = (...) ->
        @Grid_CopyCallback ...

    @moonpanel_grid\Setup @data, click, copy

editor.Serialize = () =>
    if @__serializing
        return
    @__serializing = true

    data_colors = @data.colors or {}

    outputData = {
        Tile: {
            Title: @data.title
            Width: @data.w
            Height: @data.h
            Symmetry: (@data.symmetry and @data.symmetry ~= 0) and @data.symmetry
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

    for j, row in pairs @moonpanel_grid.rows
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
                    when Moonpanel.EntityTypes.Triangle
                        t.Attributes.Count = element.attributes.count or 1

                    when Moonpanel.EntityTypes.Polyomino
                        t.Attributes.Shape = {}
                        for j = 1, element.attributes.shape.h
                            t.Attributes.Shape[j] = {}
                            for i = 1, element.attributes.shape.w
                                t.Attributes.Shape[j][i] = element.attributes.shape[j][i] and 1 or 0
                        
                        t.Attributes.Rotational = element.attributes.shape.rotational

    @__serializing = false
    return outputData

editor.Deserialize = (input) =>
    if @__serializing
        return
    @__serializing = true
    input or={}

    input_tile = input.Tile or {}
    input_dimensions = input.Dimensions or {}

    newData = {
        title: input_tile.Title
        w: input_tile.Width or 3
        h: input_tile.Height or 3
        symmetry: input_tile.Symmetry or 0
        
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

    @slider_barWidth\SetValue newData.barWidth
    @slider_innerScreenRatio\SetValue newData.innerScreenRatio
    @slider_maxBarLength\SetValue newData.maxBarLength
    @slider_disjointLength\SetValue newData.disjointLength

    @comboBox_widthCombo\SetText newData.w
    @comboBox_heightCombo\SetText newData.h
    @comboBox_symmetryCombo\SetText @comboBox_symmetryCombo\GetOptionTextByData newData.symmetry

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
                    attributes: {
                        color: hbar.Attributes and hbar.Attributes.Color
                    }
                }

            if input.VPaths and j <= h and input.VPaths[sj] and input.VPaths[sj][si]
                vbar = input.VPaths[sj][si]

                newData.vpaths[sj] or= {}
                newData.vpaths[sj][si] = {
                    entity: vbar.Type
                    attributes: {
                        color: vbar.Attributes and vbar.Attributes.Color
                    }
                }

            if input.Intersections and input.Intersections[sj] and input.Intersections[sj][si]
                int = input.Intersections[sj][si]

                newData.intersections[sj] or= {}
                newData.intersections[sj][si] = {
                    entity: int.Type
                    attributes: {
                        color: int.Attributes and int.Attributes.Color
                    }
                }
    
    table.Empty @data
    table.CopyFromTo newData, @data

    @SetupGrid @data

    @__serializing = false

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