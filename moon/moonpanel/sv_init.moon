AddCSLuaFile "moonpanel/cl_init.lua"
AddCSLuaFile "moonpanel/shared.lua"

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

resource.AddSingleFile "materials/moonpanel/acirc128.png"
resource.AddSingleFile "materials/moonpanel/circ64.png"
resource.AddSingleFile "materials/moonpanel/circ128.png"
resource.AddSingleFile "materials/moonpanel/circ256.png"
resource.AddSingleFile "materials/moonpanel/color.png"
resource.AddSingleFile "materials/moonpanel/corner64.png"
resource.AddSingleFile "materials/moonpanel/corner128.png"
resource.AddSingleFile "materials/moonpanel/corner256.png"
resource.AddSingleFile "materials/moonpanel/disjoint.png"
resource.AddSingleFile "materials/moonpanel/end.png"
resource.AddSingleFile "materials/moonpanel/eraser.png"
resource.AddSingleFile "materials/moonpanel/hex_layer1.png"
resource.AddSingleFile "materials/moonpanel/hex_layer2.png"
resource.AddSingleFile "materials/moonpanel/hexagon.png"
resource.AddSingleFile "materials/moonpanel/panel_transparent.png"
resource.AddSingleFile "materials/moonpanel/panel_transparent_a.png"
resource.AddSingleFile "materials/moonpanel/polyo.png"
resource.AddSingleFile "materials/moonpanel/polyomino_cell.png"
resource.AddSingleFile "materials/moonpanel/qcirc64.png"
resource.AddSingleFile "materials/moonpanel/qcirc128.png"
resource.AddSingleFile "materials/moonpanel/qcirc256.png"
resource.AddSingleFile "materials/moonpanel/start.png"
resource.AddSingleFile "materials/moonpanel/sun.png"
resource.AddSingleFile "materials/moonpanel/triangle.png"
resource.AddSingleFile "materials/moonpanel/slider/head.png"
resource.AddSingleFile "materials/moonpanel/slider/left.png"
resource.AddSingleFile "materials/moonpanel/slider/middle.png"
resource.AddSingleFile "materials/moonpanel/slider/notch.png"
resource.AddSingleFile "materials/moonpanel/slider/right.png"
resource.AddSingleFile "materials/moonpanel/corner64/0.png"
resource.AddSingleFile "materials/moonpanel/corner64/90.png"
resource.AddSingleFile "materials/moonpanel/corner64/180.png"
resource.AddSingleFile "materials/moonpanel/corner64/270.png"
resource.AddSingleFile "sound/moonpanel/eraser_apply.ogg"
resource.AddSingleFile "sound/moonpanel/focus_on.ogg"
resource.AddSingleFile "sound/moonpanel/focus_off.ogg"
resource.AddSingleFile "sound/moonpanel/panel_abort_tracing.ogg"
resource.AddSingleFile "sound/moonpanel/panel_failure.ogg"
resource.AddSingleFile "sound/moonpanel/panel_potential_failure.ogg"
resource.AddSingleFile "sound/moonpanel/panel_scint.ogg"
resource.AddSingleFile "sound/moonpanel/panel_start_tracing.ogg"
resource.AddSingleFile "sound/moonpanel/panel_success.ogg"

Moonpanel.setFocused = (player, state, force) =>
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
    if (ply.themp_nextrequest or 0) > CurTime!
        return

    if ply\GetNW2Entity("TheMP Controlled Panel") == ent
        ply.themp_nextrequest = CurTime! + 0.25
        if ent.FinishPuzzle
            ent\FinishPuzzle x, y
        ply\SetNW2Entity "TheMP Controlled Panel", nil
    else
        ply.themp_nextrequest = CurTime! + 0.25
        if ent.StartPuzzle
            if ent\StartPuzzle ply, x, y
                ply\SetNW2Entity "TheMP Controlled Panel", ent

Moonpanel.broadcastFinish = (panel, ply, data) =>
    net.Start "TheMP Flow"
    net.WriteUInt Moonpanel.Flow.PuzzleFinish, 8
    net.WriteEntity panel

    net.WriteEntity ply
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

    net.WriteFloat x
    net.WriteFloat y
    net.SendOmit ply

Moonpanel.sendData = (panel, ply) =>
    if ply and not IsValid ply
        return

    net.Start "TheMP Flow"
    net.WriteUInt Moonpanel.Flow.PanelData, 8
    net.WriteEntity panel

    data = {
        tileData: panel.tileData
    }

    raw = util.Compress util.TableToJSON data

    net.WriteUInt #raw, 32
    net.WriteData raw, #raw

    if IsValid ply
        net.Send ply
    else
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

        if not IsValid panel and panel
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
            ent = net.ReadEntity!

            x = net.ReadUInt 10
            y = net.ReadUInt 10

            Moonpanel\requestControl ply, ent, x, y

        when Moonpanel.Flow.ApplyDeltas
            panel = ply\GetNW2Entity "TheMP Controlled Panel"
            if IsValid panel
                x = net.ReadFloat!
                y = net.ReadFloat!

                panel\ApplyDeltas x, y

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

    pending.callback raw, length

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

