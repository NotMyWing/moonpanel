setDrawColor = surface.SetDrawColor
setScissor = render.SetScissorRect
drawRect = surface.DrawRect
white = Color 255, 255, 255, 255
setAlpha = surface.SetAlphaMultiplier
clamp = math.Clamp

SOUND_FOCUS_ON = Sound "moonpanel/focus_on.ogg"
SOUND_FOCUS_OFF = Sound "moonpanel/focus_off.ogg"

FOCUSING_TIME = 0.6

Moonpanel = Moonpanel or {}
export Moonpanel

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

    LocalPlayer!\SetNW2VarProxy "TheMP Controlled Panel", (_, _, _, new) ->
        if @isFocused!
            gui.EnableScreenClicker not IsValid new
            vgui.GetWorldPanel!\SetWorldClicker not IsValid new

    LocalPlayer!\SetNW2VarProxy "TheMP Focused", (_, _, _, new) ->
        surface.PlaySound new and SOUND_FOCUS_ON or SOUND_FOCUS_OFF
        gui.EnableScreenClicker new
        vgui.GetWorldPanel!\SetWorldClicker new

        @__focustime = CurTime!

Moonpanel.isFocused = () =>
    return LocalPlayer!\GetNW2Bool "TheMP Focused"

hook.Add "CreateMove", "TheMP Control", (cmd) ->
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
        if Moonpanel\getControlledPanel!
            if x ~= 0 or y ~= 0
                Moonpanel\sendMouseDeltas x, y
            cmd\SetMouseX 0
            cmd\SetMouseY 0
            return true

hook.Add "HUDPaint", "TheMP Focus Draw", () ->
    if not Moonpanel.__focustime
        return

    scrh, scrw = ScrH!, ScrW!

    width = math.min scrw, scrh
    width *= 0.03

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

hook.Add "Initialize", "TheMP Init", () ->
    Moonpanel\init!

if Moonpanel.__initialized
    Moonpanel\init!