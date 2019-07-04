setDrawColor = surface.SetDrawColor
setScissor = render.SetScissorRect
drawRect = surface.DrawRect
white = Color 255, 255, 255, 255
setAlpha = surface.SetAlphaMultiplier
clamp = math.Clamp

SOUND_FOCUS_ON = Sound "moonpanel/focus_on.ogg"
SOUND_FOCUS_OFF = Sound "moonpanel/focus_off.ogg"

FOCUSING_TIME = 0.6

export MOONPANEL_ENTITY_GRAPHICS = {
    [MOONPANEL_ENTITY_TYPES.HEXAGON]: (Material "moonpanel/hexagon.png", "noclamp smooth")
    [MOONPANEL_ENTITY_TYPES.SUN]: (Material "moonpanel/sun.png", "noclamp smooth")
    [MOONPANEL_ENTITY_TYPES.TRIANGLE]: (Material "moonpanel/triangle.png", "noclamp smooth")
    [MOONPANEL_ENTITY_TYPES.COLOR]: (Material "moonpanel/color.png", "noclamp smooth") 
    [MOONPANEL_ENTITY_TYPES.ERASER]: (Material "moonpanel/eraser.png", "noclamp smooth")
}

export Moonpanel = Moonpanel or {}

Moonpanel.sendMouseDeltas = (x, y) =>
    net.Start "TheMP Mouse Deltas"
    net.WriteFloat x
    net.WriteFloat y
    net.SendToServer!

Moonpanel.requestControl = (ent, x, y) =>
    net.Start "TheMP Request Control"
    net.WriteEntity ent
    net.WriteUInt x, 10
    net.WriteUInt y, 10
    net.SendToServer!

Moonpanel.getControlledPanel = () =>
    return LocalPlayer!\GetNW2Entity "TheMP Controlled Panel"

Moonpanel.init = () =>
    @__initialized = true

    if Moonpanel.editor
        Moonpanel.editor\Remove!
        Moonpanel.editor = nil

    Moonpanel.editor or= vgui.CreateFromTable (include "moonpanel/editor/cl_editor.lua")

    LocalPlayer!\SetNW2VarProxy "TheMP Controlled Panel", (_, _, _, new) ->
        if @isFocused!
            gui.EnableScreenClicker not IsValid new
            vgui.GetWorldPanel!\SetWorldClicker not IsValid new

    LocalPlayer!\SetNW2VarProxy "TheMP Focused", (_, _, _, new) ->
        surface.PlaySound new and SOUND_FOCUS_ON or SOUND_FOCUS_OFF
        gui.EnableScreenClicker new
        vgui.GetWorldPanel!\SetWorldClicker new

        @__focustime = CurTime!

    file.CreateDir "moonpanel"

Moonpanel.isFocused = () =>
    return LocalPlayer!\GetNW2Bool "TheMP Focused"

hook.Add "CreateMove", "TheMP Control", (cmd) ->
    if Moonpanel.editor and Moonpanel.editor\IsVisible!
        cmd\ClearButtons!

    if Moonpanel\isFocused!
        lastclick = Moonpanel.__nextclick or 0
        if CurTime! >= lastclick and input.WasMousePressed MOUSE_LEFT
            Moonpanel.__nextclick = CurTime! + 0.05
            ent = LocalPlayer!\GetEyeTrace!.Entity
            if IsValid(ent) and ent\GetClass! == "moonpanel"
                x, y = ent\GetCursorPos!
                if x and y
                    Moonpanel\requestControl ent, x, y

        cmd\ClearMovement!
        use = cmd\KeyDown IN_USE
        cmd\ClearButtons!
        cmd\SetButtons use and IN_USE or 0

hook.Add "InputMouseApply", "TheMP FocusMode", (cmd, x, y) ->
    if Moonpanel\isFocused! 
        panel = Moonpanel\getControlledPanel!
        if panel
            if x ~= 0 or y ~= 0
                Moonpanel\sendMouseDeltas x, y
                panel\ApplyDeltas x, y
            cmd\SetMouseX 0
            cmd\SetMouseY 0
            return true

hook.Add "HUDPaint", "TheMP Focus Draw", () ->
    if not Moonpanel.__focustime
        return

    scrh, scrw = ScrH!, ScrW!

    width = math.min scrw, scrh
    width *= 0.035
    width = math.floor width

    focus = Moonpanel\isFocused!
    alpha = clamp ((CurTime! - Moonpanel.__focustime) / FOCUSING_TIME), 0, 1
    if not focus
        alpha = 1 - alpha

    alpha = math.tanh (alpha * 8) - 4
    if alpha <= -0.99
        return

    setAlpha ((alpha + 1) / 2) * 0.2
    setDrawColor white
    drawRect 0, 0, width, scrh
    drawRect scrw - width, 0, width, scrh
    drawRect width, 0, scrw - width * 2, width
    drawRect width, scrh - width, scrw - width * 2, width

    setAlpha 1

hook.Add "InitPostEntity", "TheMP Init", () ->
    Moonpanel\init!

net.Receive "TheMP Editor", () ->
    Moonpanel.editor\Show! 
    Moonpanel.editor\MakePopup!

net.Receive "TheMP EditorData", () ->
    data = "{}"

    if Moonpanel.editor
        data = util.Compress util.TableToJSON Moonpanel.editor\Serialize!

    net.Start "TheMP EditorData"
    net.WriteUInt #data, 32
    net.WriteData data, #data
    net.SendToServer!
 
if Moonpanel.__initialized or true
    Moonpanel\init!