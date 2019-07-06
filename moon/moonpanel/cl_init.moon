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
        if IsValid panel
            if x ~= 0 or y ~= 0
                x, y = math.floor(x * 0.75), math.floor(y * 0.75)
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

net.Receive "TheMP ApplyDeltas", () ->
    panel = net.ReadEntity!
    if IsValid(panel) or not panel.ApplyDeltas
        return

    x, y = net.ReadFloat!, net.ReadFloat!

    panel\ApplyDeltas x, y

net.Receive "TheMP NodeStacks", (len) ->
    print len
    stacks, curs = {}, {}

    panel = net.ReadEntity!
    if IsValid panel
        return

    stackCount = net.ReadUInt 4
    for i = 1, stackCount
        pointCount = net.ReadUInt 10
        stack = {}
        for j = 1, pointCount
            stack[#stack + 1] = {
                x: net.ReadUInt 10
                y: net.ReadUInt 10
            }

        stacks[#stacks + 1] = stack

    curCount = net.ReadUInt 4
    for i = 1, curCount
        curs[#curs + 1] = {
            x: net.ReadUInt 10
            y: net.ReadUInt 10
        }

    panel.shouldRepaintTrace = true

net.Receive "TheMP EditorData Req", () ->
    data = "{}"

    if Moonpanel.editor
        data = util.Compress util.TableToJSON Moonpanel.editor\Serialize!

    net.Start "TheMP EditorData"
    net.WriteUInt #data, 32
    net.WriteData data, #data
    net.SendToServer!
 
net.Receive "TheMP Start", () ->
    panel = net.ReadEntity!
    _nodeA, nodeB = {
        x: net.ReadFloat!
        y: net.ReadFloat!
    }, nil
    if net.ReadBool!
        _nodeB = {
            x: net.ReadFloat!
            y: net.ReadFloat!
        }

    if IsValid(panel) and panel.pathFinder
        nodeA, nodeB = nil, nil
        if _nodeA
            for _, node in pairs panel.pathFinder.nodeMap
                if node.x == _nodeA.x and node.y == _nodeA.y
                    nodeA = node
                    break

        if _nodeB
            for _, node in pairs panel.pathFinder.nodeMap
                if node.x == _nodeB.x and node.y == _nodeB.y
                    nodeB = node
                    break

        if nodeA
            panel.pathFinder\restart nodeA, nodeB
            panel.shouldRepaintTrace = true

net.Receive "TheMP Finish", () ->
    panel = net.ReadEntity!
    success = net.ReadBool!
    redOut = net.ReadTable!
    grayOut = net.ReadTable!

    if IsValid(panel) and panel.PuzzleFinish
        panel\PuzzleFinish success, redOut, grayOut

if Moonpanel.__initialized or true
    Moonpanel\init!

------------
-- Render --
------------

-- https://github.com/thegrb93/StarfallEx
quad_v1, quad_v2, quad_v3, quad_v4 = Vector(0,0,0), Vector(0,0,0), Vector(0,0,0), Vector(0,0,0)

Moonpanel.render = {}

makeQuad = (x, y, w, h) ->
	right, bot = x + w, y + h
	quad_v1.x = x
	quad_v1.y = y
	quad_v2.x = right
	quad_v2.y = y
	quad_v3.x = right
	quad_v3.y = bot
	quad_v4.x = x
	quad_v4.y = bot

Moonpanel.render.drawTexturedRect = (x, y, w, h, color) ->
	makeQuad x, y, w, h
	render.DrawQuad quad_v1, quad_v2, quad_v3, quad_v4, color

Moonpanel.render.drawThickLine = (x1, y1, x2, y2, width) ->
    angle = math.deg math.atan2 (y2 - y1), (x2 - x1)
    dist = math.sqrt (y2 - y1)^2 + (x2 - x1)^2

    matrix = Matrix!
    matrix\Translate Vector x2, y2, 0
    matrix\Rotate Angle 0, angle + 90, 0
    cam.PushModelMatrix matrix

    surface.DrawRect -width / 2, 0, width, dist

    cam.PopModelMatrix!

circ = Material "moonpanel/circ128.png"

Moonpanel.render.drawCircle = (x, y, r) ->
    render.SetMaterial circ
    Moonpanel.render.drawTexturedRect x - r, y - r, r * 2, r * 2
    render.SetColorMaterial!