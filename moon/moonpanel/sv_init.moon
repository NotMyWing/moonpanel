AddCSLuaFile "moonpanel/cl_init.lua"
AddCSLuaFile "moonpanel/shared.lua"

AddCSLuaFile "moonpanel/panel/sh_pathfinder.lua"
AddCSLuaFile "moonpanel/panel/sh_elements.lua"
AddCSLuaFile "moonpanel/panel/ents/sh_cell.lua"
AddCSLuaFile "moonpanel/panel/ents/sh_path.lua"
AddCSLuaFile "moonpanel/panel/ents/sh_intersection.lua"

AddCSLuaFile "moonpanel/editor/cl_editor.lua"
AddCSLuaFile "moonpanel/editor/vgui_panel.lua"
AddCSLuaFile "moonpanel/editor/vgui_cell.lua"
AddCSLuaFile "moonpanel/editor/vgui_vpath.lua"
AddCSLuaFile "moonpanel/editor/vgui_hpath.lua"
AddCSLuaFile "moonpanel/editor/vgui_intersection.lua"
AddCSLuaFile "moonpanel/editor/vgui_polyoeditor.lua"
AddCSLuaFile "moonpanel/editor/vgui_circlyslider.lua"

AddCSLuaFile "entities/moonpanel/shared.lua"
AddCSLuaFile "entities/moonpanel/cl_init.lua"

util.AddNetworkString "TheMP EditorData Req"
util.AddNetworkString "TheMP EditorData"

util.AddNetworkString "TheMP Flow"

util.AddNetworkString "TheMP Editor"
util.AddNetworkString "TheMP Focus"
util.AddNetworkString "TheMP Notify"

resource.AddSingleFile "materials/moonpanel/acirc128.png"
resource.AddSingleFile "materials/moonpanel/circ64.png"
resource.AddSingleFile "materials/moonpanel/circ128.png"
resource.AddSingleFile "materials/moonpanel/circ256.png"
resource.AddSingleFile "materials/moonpanel/color.png"
resource.AddSingleFile "materials/moonpanel/disjoint.png"
resource.AddSingleFile "materials/moonpanel/end.png"
resource.AddSingleFile "materials/moonpanel/eraser.png"
resource.AddSingleFile "materials/moonpanel/hex_layer1.png"
resource.AddSingleFile "materials/moonpanel/hex_layer2.png"
resource.AddSingleFile "materials/moonpanel/hexagon.png"
resource.AddSingleFile "materials/moonpanel/panel_transparent.png"
resource.AddSingleFile "materials/moonpanel/polyo.png"
resource.AddSingleFile "materials/moonpanel/polyomino_cell.png"
resource.AddSingleFile "materials/moonpanel/start.png"
resource.AddSingleFile "materials/moonpanel/sun.png"
resource.AddSingleFile "materials/moonpanel/triangle.png"
resource.AddSingleFile "materials/moonpanel/slider/head.png"
resource.AddSingleFile "materials/moonpanel/slider/left.png"
resource.AddSingleFile "materials/moonpanel/slider/middle.png"
resource.AddSingleFile "materials/moonpanel/slider/notch.png"
resource.AddSingleFile "materials/moonpanel/slider/right.png"
resource.AddSingleFile "materials/moonpanel/corner128/0.png"
resource.AddSingleFile "materials/moonpanel/corner128/90.png"
resource.AddSingleFile "materials/moonpanel/corner128/180.png"
resource.AddSingleFile "materials/moonpanel/corner128/270.png"
resource.AddSingleFile "materials/moonpanel/vignette.png"
resource.AddSingleFile "materials/moonpanel/editor_bucket.png"
resource.AddSingleFile "materials/moonpanel/editor_brush.png"
resource.AddSingleFile "materials/moonpanel/editor_eraser.png"
resource.AddSingleFile "materials/moonpanel/icon16_windmill.png"
resource.AddSingleFile "materials/moonpanel/cell_nocalc.png"
resource.AddSingleFile "materials/moonpanel/invisible_layer1.png"
resource.AddSingleFile "materials/moonpanel/invisible_layer2.png"
resource.AddSingleFile "materials/moonpanel/cross.png"
resource.AddSingleFile "sound/moonpanel/eraser_apply.ogg"
resource.AddSingleFile "sound/moonpanel/focus_on.ogg"
resource.AddSingleFile "sound/moonpanel/focus_off.ogg"
resource.AddSingleFile "sound/moonpanel/panel_abort_tracing.ogg"
resource.AddSingleFile "sound/moonpanel/panel_failure.ogg"
resource.AddSingleFile "sound/moonpanel/panel_potential_failure.ogg"
resource.AddSingleFile "sound/moonpanel/panel_scint.ogg"
resource.AddSingleFile "sound/moonpanel/panel_start_tracing.ogg"
resource.AddSingleFile "sound/moonpanel/panel_success.ogg"
resource.AddSingleFile "sound/moonpanel/powered_on.ogg"
resource.AddSingleFile "sound/moonpanel/powered_off.ogg"

Moonpanel.setFocused = (player, state, force) =>
    if state and (
        player\KeyDown(IN_RUN) or 
        player\KeyDown(IN_DUCK) or
        player\KeyDown(IN_ATTACK) or
        player\KeyDown(IN_ATTACK2) or
        player\KeyDown(IN_ALT1) or
        player\KeyDown(IN_ALT2) or
        player\KeyDown(IN_WEAPON1) or
        player\KeyDown(IN_WEAPON2) or
        player\KeyDown(IN_BULLRUSH) or
        player\KeyDown(IN_SPEED) or
        player\KeyDown(IN_WALK)
    ) 
        return

    time = player.themp_lastfocuschange or 0

    if force or (CurTime! >= time and state ~= player\GetNW2Bool "TheMP Focused")
        if (state ~= player\GetNW2Bool "TheMP Focused")
            if state
                weap = player\GetActiveWeapon!
                if IsValid weap
                    player.themp_oldweapon = weap\GetClass!
                if not player\HasWeapon "none"
                    player\Give "none"
                    player.themp_givenhands = true
            else
                player\SetNW2Entity "TheMP Controlled Panel", nil
                player\SelectWeapon player.themp_oldweapon or "none"
                if player.themp_givenhands
                    player.themp_givenhands = nil
                    player\StripWeapon "none"

        player\SetNW2Bool "TheMP Focused", state

        player.themp_lastfocuschange = CurTime! + 0.75

Moonpanel.isFocused = (ply) =>
    return ply\GetNW2Bool "TheMP Focused"

Moonpanel.getControlledPanel = (ply) =>
    return ply\GetNW2Entity "TheMP Controlled Panel" 

Moonpanel.requestControl = (ply, ent, x, y, force) =>
    if not IsValid ent
        return

    if (ply.themp_nextrequest or 0) > CurTime!
        return

    if ply\GetNW2Entity("TheMP Controlled Panel") == ent
        ply.themp_nextrequest = CurTime! + 0.25
        if ent.Moonpanel
            ent\FinishPuzzle!
        ply\SetNW2Entity "TheMP Controlled Panel", nil
    else
        ply.themp_nextrequest = CurTime! + 0.25
        if ent.Moonpanel
            if ent\StartPuzzle ply, x, y
                ply\SetNW2Entity "TheMP Controlled Panel", ent

Moonpanel.sendNotify = (ply, message, sound, type) =>
    net.Start "TheMP Notify"
    net.WriteString message
    net.WriteString sound
    net.WriteUInt type, 8
    net.Send ply

Moonpanel.broadcastFinish = (panel, data) =>
    net.Start "TheMP Flow"
    net.WriteUInt Moonpanel.Flow.PuzzleFinish, 8
    net.WriteEntity panel

    raw = util.Compress util.TableToJSON data
    net.WriteUInt #raw, 32
    net.WriteData raw, #raw

    net.Broadcast!

Moonpanel.broadcastStart = (panel, node, symmNode) =>
    net.Start "TheMP Flow"
    net.WriteUInt Moonpanel.Flow.PuzzleStart, 8
    net.WriteEntity panel

    net.WriteFloat node.x
    net.WriteFloat node.y
    net.WriteBool symmNode and true or false

    if symmNode
        net.WriteFloat symmNode.x
        net.WriteFloat symmNode.y
    net.Broadcast!

Moonpanel.broadcastNodeStacks = (ply, panel, nodeStacks, cursors) =>
    net.Start "TheMP NodeStacks"
    net.WriteEntity panel
    net.WriteUInt #nodeStacks, 4
    for _, stack in pairs nodeStacks
        net.WriteUInt #stack, 10
        for _, point in pairs stack
            net.WriteUInt point.sx, 10
            net.WriteUInt point.sy, 10

    net.WriteUInt #cursors, 4
    for _, cursor in pairs cursors
        net.WriteUInt cursor.x, 10
        net.WriteUInt cursor.y, 10

    net.SendOmit ply

Moonpanel.broadcastDeltas = (ply, panel, x, y) =>
    net.Start "TheMP Flow"
    net.WriteUInt Moonpanel.Flow.ApplyDeltas, 8
    net.WriteEntity panel

    x, y = math.Clamp(math.floor(x), -100, 100), math.Clamp(math.floor(y), -100, 100)
    net.WriteInt x, 8
    net.WriteInt y, 8
    net.SendOmit ply

Moonpanel.broadcastDesync = (panel) =>
    net.Start "TheMP Flow"
    net.WriteUInt Moonpanel.Flow.Desync, 8
    net.WriteEntity panel
    net.Broadcast!

hook.Add "KeyPress", "TheMP Focus", (ply, key) ->
    tr = ply\GetEyeTrace!

    if key == IN_USE
        if not ply\GetNW2Bool "TheMP Focused"
            timer.Simple 0, () ->
                if tr and IsValid(tr.Entity) and tr.Entity.ApplyDeltas and not tr.Entity\IsPlayerHolding!
                    Moonpanel\setFocused ply, true
        else
            Moonpanel\setFocused ply, false
    if key == IN_ATTACK and (Moonpanel\isFocused ply) 
        Moonpanel\requestControl ply, ply\GetNW2Entity("TheMP Controlled Panel"), x, y

hook.Add "Think", "TheMP Think", () ->
    for k, v in pairs player.GetAll!
        panel = v\GetNW2Entity("TheMP Controlled Panel")

        if not IsValid panel
            v\SetNW2Entity("TheMP Controlled Panel", nil)

        if IsValid(panel) and panel\GetNW2Entity("ActiveUser") ~= v
            v\SetNW2Entity("TheMP Controlled Panel", nil)

        if v\GetNW2Bool "TheMP Focused"
            v\SelectWeapon "none"

hook.Add "PostPlayerDeath", "TheMP PlayerDeath", (ply) ->
    Moonpanel\setFocused ply, false, true

hook.Add "PlayerSilentDeath", "TheMP PlayerDeath", (ply) ->
    Moonpanel\setFocused ply, false, true

net.Receive "TheMP Flow", (len, ply) ->
    flowType = net.ReadUInt 8
    
    switch flowType
        when Moonpanel.Flow.RequestControl
            panel = net.ReadEntity!

            x = net.ReadUInt 10
            y = net.ReadUInt 10

            Moonpanel\requestControl ply, panel, x, y

        when Moonpanel.Flow.ApplyDeltas
            panel = ply\GetNW2Entity "TheMP Controlled Panel"
            if IsValid panel
                x = net.ReadInt 8
                y = net.ReadInt 8

                panel\ApplyDeltas x, y

        when Moonpanel.Flow.RequestData
            panel = net.ReadEntity!
            if not panel.pathFinder
                return

            data = {
                tileData: panel.tileData
                cursors: panel.pathFinder.cursors
                lastSolution: panel.lastSolution
            }

            data.stacks = {}
            for _, nodeStack in pairs panel.pathFinder.nodeStacks
                stack = {}
                data.stacks[#data.stacks + 1] = stack

                for _, node in pairs nodeStack
                    stack[#stack + 1] = panel.pathFinder.nodeIds[node]

            raw = util.Compress util.TableToJSON data

            net.Start "TheMP Flow"
            net.WriteUInt Moonpanel.Flow.PanelData, 8

            net.WriteEntity panel
            net.WriteUInt #raw, 32
            net.WriteData raw, #raw

            net.Send ply

net.Receive "TheMP EditorData", (len, ply) ->
    pending = nil
    pendingEditorData = Moonpanel.pendingEditorData

    for k, v in pairs pendingEditorData
        if v.player == ply
            pending = v
            break

    if not pending
        return

    for i = 1, #pendingEditorData
        if pendingEditorData[i] == pending
            table.remove pendingEditorData, i
            break

    timer.Remove pending.timer

    length = net.ReadUInt 32
    raw = net.ReadData length
    
    data = util.JSONToTable((util.Decompress raw) or "{}") or {}
    data = Moonpanel\sanitizeTileData data

    pending.callback data

Moonpanel.pendingEditorData = {}
pendingEditorData = Moonpanel.pendingEditorData

counter = 1
Moonpanel.requestEditorConfig = (ply, callback, errorcallback) =>
    pending = {
        player: ply
        callback: callback
        timer: "TheMP RemovePending #{tostring counter}"
    }
    pendingEditorData[#pendingEditorData + 1] = pending

    counter = (counter % 10000) + 1

    net.Start "TheMP EditorData Req"
    net.Send ply
    
    timer.Create pending.timer, 4, 1, () ->
        errorcallback!
        for i = 1, #pendingEditorData
            if pendingEditorData[i] == pending
                table.remove pendingEditorData, i
                break

sanitizeColor = (clr, template) ->
    clr or= {}
    out = {}

    r = clr.r and tonumber(clr.r)
    out.r = (r and math.Clamp(r, 0, 255)) or template.r or 255

    g = clr.g and tonumber(clr.g)
    out.g = (g and math.Clamp(g, 0, 255)) or template.g or 255

    b = clr.b and tonumber(clr.b)
    out.b = (b and math.Clamp(b, 0, 255)) or template.b or 255

    a = clr.a and tonumber(clr.a)
    out.a = (a and math.Clamp(a, 0, 255)) or template.a or 255

    return Color out.r, out.g, out.b, out.a

sanitizeNumber = (num, default) ->
    return tonumber(num) and tonumber(num) or default

Moonpanel.sanitizeTileData = (input) =>
    input or= {}
    input.Tile or= {}
    input.Dimensions or= {}
    input.HPaths or= {}
    input.VPaths or= {}
    input.Intersections or= {}
    input.Cells or= {}
    input.Colors or= {}

    sanitized = {
        Tile: {
            Title: input.Tile.Title and string.sub(input.Tile.Title, 1, 64) or nil
            Width: math.Clamp((sanitizeNumber input.Tile.Width, 3), 1, 10)
            Height: math.Clamp((sanitizeNumber input.Tile.Height, 3), 1, 10)
            Symmetry: input.Tile.Symmetry and (math.floor math.Clamp((sanitizeNumber input.Tile.Symmetry, 0), 0, 3)) or 0
        }
        Dimensions: {
            BarWidth: input.Dimensions.BarWidth and
                math.Clamp((sanitizeNumber input.Dimensions.BarWidth, 3), 0, 1)

            InnerScreenRatio: input.Dimensions.InnerScreenRatio and
                math.Clamp((sanitizeNumber input.Dimensions.InnerScreenRatio, 3), 0, 1)

            MaxBarLength: input.Dimensions.MaxBarLength and
                math.Clamp((sanitizeNumber input.Dimensions.MaxBarLength, 3), 0, 1)

            DisjointLength: input.Dimensions.DisjointLength and
                math.Clamp((sanitizeNumber input.Dimensions.DisjointLength, 3), 0, 1)
        }
        Cells: {}
        Intersections: {}
        VPaths: {}
        HPaths: {}
    }

    colors = input.Colors or {}
    defaults = Moonpanel.DefaultColors

    sanitized.Colors = {}
    sanitized.Colors.Untraced   = sanitizeColor colors.Untraced, defaults.Untraced
    sanitized.Colors.Traced     = sanitizeColor colors.Traced, defaults.Traced
    sanitized.Colors.Finished   = sanitizeColor colors.Finished, defaults.Finished
    sanitized.Colors.Errored    = sanitizeColor colors.Errored, defaults.Errored
    sanitized.Colors.Background = sanitizeColor colors.Background, defaults.Background
    sanitized.Colors.Vignette   = sanitizeColor colors.Vignette, defaults.Vignette
    sanitized.Colors.Cell       = sanitizeColor colors.Cell, defaults.Cell

    MAXENT = 10
    MAXCOLOR = 9

    w, h = sanitized.Tile.Width, sanitized.Tile.Height
    for j = 1, h + 1
        for i = 1, w + 1
            si, sj = i, j

            if input.Cells and j <= h and i <= w and input.Cells[sj] and input.Cells[sj][si]
                cell = input.Cells[sj][si]
                atts = cell.Attributes or {}

                sanitized.Cells[sj] or= {}
                sanitized.Cells[sj][si] = {
                    Type: math.floor math.Clamp((sanitizeNumber cell.Type, 1), 0, MAXENT)
                }

                newAtts = {
                    Color: math.floor math.Clamp((sanitizeNumber atts.Color, 1), 1, #Moonpanel.Colors)
                    Count: atts.Count and (math.floor math.Clamp((sanitizeNumber atts.Count, 1), 1, 3))
                }

                sanitized.Cells[sj][si].Attributes = newAtts

                if atts.Shape
                    maxlen = nil 
                    for _j, row in pairs atts.Shape
                        if not maxlen or #row > maxlen
                            maxlen = #row
                    
                    if maxlen and maxlen > 0
                        maxlen = math.Clamp maxlen, 1, 5

                        shape = {}
                        
                        atLeastOneTrue = false
                        for _j, row in pairs atts.Shape
                            shape[_j] = {}
                            for _i = 1, maxlen
                                shape[_j][_i] = (row[_i] == 1) and 1 or 0
                                atLeastOneTrue = true
                        
                        if atLeastOneTrue
                            newAtts.Shape = shape
                            newAtts.Rotational = atts.Rotational and true or false

            if input.HPaths and i <= w and input.HPaths[sj] and input.HPaths[sj][si]
                hbar = input.HPaths[sj][si]
                atts = hbar.Attributes or {}

                sanitized.HPaths[sj] or= {}
                sanitized.HPaths[sj][si] = {
                    Type: math.floor math.Clamp((sanitizeNumber hbar.Type, 1), 0, MAXENT)
                    Attributes: {
                        Color: math.floor math.Clamp((sanitizeNumber atts.Color, 1), 1, #Moonpanel.Colors)
                    }
                }

            if input.VPaths and j <= h and input.VPaths[sj] and input.VPaths[sj][si]
                vbar = input.VPaths[sj][si]
                atts = vbar.Attributes or {}

                sanitized.VPaths[sj] or= {}
                sanitized.VPaths[sj][si] = {
                    Type: math.floor math.Clamp((sanitizeNumber vbar.Type, 1), 0, MAXENT)
                    Attributes: {
                        Color: math.floor math.Clamp((sanitizeNumber atts.Color, 1), 1, #Moonpanel.Colors)
                    }
                }

            if input.Intersections and input.Intersections[sj] and input.Intersections[sj][si]
                int = input.Intersections[sj][si]
                atts = int.Attributes or {}

                sanitized.Intersections[sj] or= {}
                sanitized.Intersections[sj][si] = {
                    Type: math.floor math.Clamp((sanitizeNumber int.Type, 1), 0, MAXENT)
                    Attributes: {
                        Color: math.floor math.Clamp((sanitizeNumber atts.Color, 1), 1, #Moonpanel.Colors)
                    }
                }

    return sanitized