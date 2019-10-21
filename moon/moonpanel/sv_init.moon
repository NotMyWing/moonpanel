include "moonpanel/sv_net.lua"
include "moonpanel/sv_hooks.lua"

AddCSLuaFile "moonpanel/cl_init.lua"
AddCSLuaFile "moonpanel/cl_net.lua"
AddCSLuaFile "moonpanel/cl_circles.lua"
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

sounds = {
    "eraser_apply.ogg"
    "focus_on.ogg"
    "focus_off.ogg"
    "panel_abort_tracing.ogg"
    "panel_failure.ogg"
    "panel_potential_failure.ogg"
    "panel_scint.ogg"
    "panel_start_tracing.ogg"
    "panel_success.ogg"
    "powered_on.ogg"
    "powered_off.ogg"
    "panel_path_complete_loop.wav"
    "panel_solving_loop.wav"
    "panel_presence_loop.wav"
    "panel_finish_tracing.ogg"
    "panel_abort_finish_tracing.ogg"
}

materials = {
    "editor/cell_nocalc.png"
    "editor/invisible_layer1.png"
    "editor/invisible_layer2.png"
    "editor/cross.png"
    "editor/disjoint.png"
    "editor/tool_brush.png"
    "editor/tool_eraser.png"
    "editor/tool_bucket.png"
    "editor/end.png"
    "editor/start.png"
    "editor/hex_layer1.png"
    "editor/hex_layer2.png"
    "editor/icon16_windmill.png"
    "editor/panel.png"
    "editor/polyo.png"
    "editor/corner128/0.png"
    "editor/corner128/1.png"
    "editor/corner128/2.png"
    "editor/corner128/3.png"
    "editor/slider/head.png"
    "editor/slider/left.png"
    "editor/slider/middle.png"
    "editor/slider/right.png"
    "editor/slider/notch.png"

    "common/color.png"
    "common/eraser.png"
    "common/hexagon.png"
    "common/polyomino_cell.png"
    "common/triangle.png"
    "common/sun.png"
    "common/vignette.png"

    "panel/translucent.vtf"
}

for _, sound in pairs sounds
    resource.AddSingleFile "sound/moonpanel/#{sound}"

for _, mat in pairs materials
    resource.AddSingleFile "materials/moonpanel/#{mat}"

keysToIgnore = {
    IN_RUN
    IN_DUCK
    IN_ATTACK
    IN_ATTACK2
    IN_ALT1
    IN_ALT2
    IN_WEAPON1
    IN_WEAPON2
    IN_BULLRUSH
    IN_SPEED
    IN_WALK
}

isIgnoredKeyPressed = (ply) ->
    for _, key in pairs keysToIgnore
        if ply\KeyDown key
            return true

    return false

Moonpanel.setFocused = (ply, state, force) =>
    if not IsValid(ply) or (state and isIgnoredKeyPressed ply)
        return

    time = ply.themp_lastfocuschange or 0

    if state ~= (ply\GetNW2Bool "TheMP Focused") and (force or (CurTime! >= time))
        if (state ~= ply\GetNW2Bool "TheMP Focused")
            if state
                weap = ply\GetActiveWeapon!
                if IsValid weap
                    ply.themp_oldweapon = weap\GetClass!
                if not ply\HasWeapon "none"
                    ply\Give "none"
                    ply.themp_givenhands = true
            else
                ply\SetNW2Entity "TheMP Controlled Panel", nil
                ply\SelectWeapon ply.themp_oldweapon or "none"
                if ply.themp_givenhands
                    ply.themp_givenhands = nil
                    ply\StripWeapon "none"

        ply\SetNW2Bool "TheMP Focused", state

        ply.themp_lastfocuschange = CurTime! + 0.75

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
    num = tonumber(num)
    return num and num or default

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
                        Hollow: not not atts.Hollow
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
                        Hollow: not not atts.Hollow
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
                        Hollow: not not atts.Hollow
                    }
                }

    return sanitized