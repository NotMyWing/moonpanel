AddCSLuaFile "moonpanel/cl_init.lua"
AddCSLuaFile "moonpanel/shared.lua"

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

util.AddNetworkString "TheMP Editor"
util.AddNetworkString "TheMP Focus"
util.AddNetworkString "TheMP Mouse Deltas"
util.AddNetworkString "TheMP Request Control"

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
        ent\FinishPuzzle x, y
        ply\SetNW2Entity "TheMP Controlled Panel", nil
    else
        ply.themp_nextrequest = CurTime! + 0.25
        if ent\StartPuzzle ply, x, y
            ply\SetNW2Entity "TheMP Controlled Panel", ent

Moonpanel.broadcastData = (raw, length, ent) =>
    net.Start "TheMP EditorData"
    net.WriteUInt length, 32
    net.WriteData raw, length
    net.WriteEntity ent
    net.Broadcast!

hook.Add "KeyPress", "TheMP Focus", (ply, key) ->
    if key == IN_USE
        Moonpanel\setFocused ply, false
    if key == IN_ATTACK and (Moonpanel\isFocused ply) and IsValid Moonpanel\getControlledPanel ply
        Moonpanel\requestControl ply, (Moonpanel\getControlledPanel ply), x, y

hook.Add "Think", "TheMP Think", () ->
    for k, v in pairs player.GetAll!
        if v\GetNW2Bool "TheMP Focused"
            v\SelectWeapon "none"

hook.Add "PostPlayerDeath", "TheMP PlayerDeath", (ply) ->
    Moonpanel\setFocused ply, false, true

hook.Add "PlayerSilentDeath", "TheMP PlayerDeath", (ply) ->
    Moonpanel\setFocused ply, false, true

net.Receive "TheMP Request Control", (len, ply) ->
    ent = net.ReadEntity!
    x = net.ReadUInt 10
    y = net.ReadUInt 10

    Moonpanel\requestControl ply, ent, x, y

net.Receive "TheMP Mouse Deltas", (len, ply) ->
    panel = ply\GetNW2Entity("TheMP Controlled Panel")
    if IsValid panel
        x = net.ReadFloat!
        y = net.ReadFloat!

        panel\ApplyDeltas x, y

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

