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
    [Moonpanel.EntityTypes.Hexagon]: (Material "moonpanel/hexagon.png", "noclamp smooth")
    [Moonpanel.EntityTypes.Sun]: (Material "moonpanel/sun.png", "noclamp smooth")
    [Moonpanel.EntityTypes.Triangle]: (Material "moonpanel/triangle.png", "noclamp smooth")
    [Moonpanel.EntityTypes.Color]: (Material "moonpanel/color.png", "noclamp smooth") 
    [Moonpanel.EntityTypes.Eraser]: (Material "moonpanel/eraser.png", "noclamp smooth")
}

export Moonpanel = Moonpanel or {}

Moonpanel.applyDeltas = (panel, x = 0, y = 0) =>
    x, y = math.Clamp(math.floor(x), -100, 100), math.Clamp(math.floor(y), -100, 100)

    Moonpanel\sendMouseDeltas x, y
    panel\ApplyDeltas x, y

Moonpanel.sendMouseDeltas = (x, y) =>
    net.Start "TheMP Flow"
    net.WriteUInt Moonpanel.Flow.ApplyDeltas, 8

    net.WriteInt x, 8
    net.WriteInt y, 8
    net.SendToServer!

Moonpanel.requestControl = (ent, x, y) =>
    net.Start "TheMP Flow"
    net.WriteUInt Moonpanel.Flow.RequestControl, 8

    net.WriteEntity ent
    net.WriteUInt x, 10
    net.WriteUInt y, 10
    net.SendToServer!

Moonpanel.requestData = (ent) =>
    net.Start "TheMP Flow"
    net.WriteUInt Moonpanel.Flow.RequestData, 8

    net.WriteEntity ent
    net.SendToServer!

Moonpanel.getControlledPanel = () =>
    panel = LocalPlayer!\GetNW2Entity "TheMP Controlled Panel"
    return panel

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
        clicked = input.WasMousePressed MOUSE_LEFT
        panel = Moonpanel\getControlledPanel!
        lastclick = Moonpanel.__nextclick or 0

        if CurTime! >= lastclick and clicked
            Moonpanel.__nextclick = CurTime! + 0.05
            ent = LocalPlayer!\GetEyeTrace!.Entity
            if IsValid(ent) and ent.Moonpanel
                x, y = ent\GetCursorPos!
                if x and y
                    Moonpanel\requestControl ent, x, y

            elseif IsValid(panel) and panel.Moonpanel
                Moonpanel\requestControl panel, 0, 0

        if IsValid(panel) and CurTime! >= (Moonpanel.__nextMovementSend or 0)
            y = -cmd\GetForwardMove!
            x = cmd\GetSideMove!

            x = ((x > 0 and 1) or (x < 0 and -1) or 0) * 10
            y = ((y > 0 and 1) or (y < 0 and -1) or 0) * 10

            if x ~= 0 or y ~= 0
                Moonpanel.__nextMovementSend = CurTime! + 0.01
                Moonpanel\applyDeltas panel, x, y
        
        if IsValid panel
            cmd\ClearMovement!

        use = cmd\KeyDown IN_USE
        cmd\ClearButtons!
        cmd\SetButtons use and IN_USE or 0
        cmd\SetMouseX 0
        cmd\SetMouseY 0

hook.Add "InputMouseApply", "TheMP FocusMode", (cmd, x, y) ->
    if Moonpanel\isFocused! 
        panel = Moonpanel\getControlledPanel!
        if IsValid panel
            if x ~= 0 or y ~= 0
                x, y = x * 0.75, y * 0.75
                Moonpanel\applyDeltas panel, x, y
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

net.Receive "TheMP NodeStacks", (len) ->
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
 
net.Receive "TheMP Flow", () ->
    flowType = net.ReadUInt 8
    panel = net.ReadEntity!

    if not IsValid panel
        return

    switch flowType
        when Moonpanel.Flow.PuzzleStart
            if not panel.Moonpanel or not panel.synchronized
                return

            _nodeA, _nodeB = {
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
                    panel\PuzzleStart nodeA, nodeB
        
        when Moonpanel.Flow.ApplyDeltas
            if not panel.Moonpanel or not panel.synchronized
                return

            x, y = net.ReadInt(8), net.ReadInt(8)

            panel\ApplyDeltas x, y

        when Moonpanel.Flow.PuzzleFinish
            if not panel.Moonpanel or not panel.synchronized
                return

            len = net.ReadUInt 32
            data = util.JSONToTable(util.Decompress(net.ReadData(len)) or "{}") or {}

            panel\PuzzleFinish data

        when Moonpanel.Flow.PanelData
            if not panel.Moonpanel or panel.synchronized
                return

            length = net.ReadUInt 32
            raw = net.ReadData length

            data = util.JSONToTable((util.Decompress raw) or "{}") or {}

            panel\SetupData data

if Moonpanel.__initialized
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
    angle = math.Round math.deg math.atan2 (y2 - y1), (x2 - x1)
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

Moonpanel.render.createRipple = (x, y, rad, framecount = 100) ->
    ripple = {
        :framecount
    }
    ripple.frames = {}
    for i = 1, framecount
        r = (i / framecount) * rad
        ripple.frames[#ripple.frames + 1] = {
            arc: Moonpanel.render.precacheArc x, y, r, rad * 0.07, -180, 180, 30
            alpha: (1 - (i / framecount)) * 255
        }
    
    return ripple

Moonpanel.render.drawRipple = (ripple, frame, color) ->
    f = ripple.frames[math.ceil frame * ripple.framecount]
    if not f
        return

    clr = ColorAlpha color, f.alpha
    surface.SetDrawColor clr
    Moonpanel.render.drawArc f.arc

Moonpanel.render.precacheArc = (cx,cy,radius,thickness,startang,endang,roughness) ->
    triarc = {}
    -- local deg2rad = math.pi / 180
    
    -- Define step
    roughness = math.max(roughness or 1, 1)
    step = roughness
    
    -- Correct start/end ang
    startang,endang = startang or 0, endang or 0
    
    if startang > endang
        step = math.abs(step) * -1
    
    -- Create the inner circle's points.
    inner = {}
    r = radius - thickness
    for deg=startang, endang, step
        rad = math.rad(deg)
        -- local rad = deg2rad * deg
        ox, oy = cx+(math.cos(rad)*r), cy+(-math.sin(rad)*r)
        table.insert(inner, {
            x: ox,
            y: oy,
            u: (ox-cx)/radius + .5,
            v: (oy-cy)/radius + .5,
        })
    
    -- Create the outer circle's points.
    outer = {}
    for deg=startang, endang, step
        rad = math.rad(deg)
        -- local rad = deg2rad * deg
        ox, oy = cx+(math.cos(rad)*radius), cy+(-math.sin(rad)*radius)
        table.insert(outer, {
            x: ox,
            y: oy,
            u: (ox-cx)/radius + .5,
            v: (oy-cy)/radius + .5,
        })

    -- Triangulize the points.
    for tri=1,#inner*2 -- twice as many triangles as there are degrees.
        p1,p2,p3
        p1 = outer[math.floor(tri/2)+1]
        p3 = inner[math.floor((tri+1)/2)+1]
        if tri%2 == 0 --if the number is even use outer.
            p2 = outer[math.floor((tri+1)/2)]
        else
            p2 = inner[math.floor((tri+1)/2)]

        table.insert(triarc, {p1,p2,p3})

    -- Return a table of triangles to draw.
    return triarc

Moonpanel.render.drawArc = (arc) ->
    for k,v in ipairs(arc)
        surface.DrawPoly(v)