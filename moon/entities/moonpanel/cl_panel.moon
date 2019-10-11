import SetDrawColor, DrawRect from surface
import Clear, ClearDepth, OverrideAlphaWriteEnable from render
import SetStencilEnable, SetViewPort, SetColorMaterial, PushRenderTarget, PopRenderTarget from render

RT_Material = CreateMaterial "TheMP_RT", "UnlitGeneric", {
    ["$nolod"]: 1,
    ["$ignorez"]: 1,
    ["$vertexcolor"]: 1,
    ["$vertexalpha"]: 1
    ["$noclamp"]: 1
    ["$nocull"]: 1
}

REDOUT_TIME = 10
POWERSTATE_TIME = 1
RESYNC_ATTEMPT_TIME = 0.5

SOUND_PANEL_SCINT = Sound "moonpanel/panel_scint.ogg"
SOUND_PANEL_FAILURE = Sound "moonpanel/panel_failure.ogg"
SOUND_PANEL_POTENTIAL_FAILURE = Sound "moonpanel/panel_potential_failure.ogg"
SOUND_PANEL_SUCCESS = Sound "moonpanel/panel_success.ogg"
SOUND_PANEL_START = Sound "moonpanel/panel_start_tracing.ogg"
SOUND_PANEL_ERASER = Sound "moonpanel/eraser_apply.ogg"
SOUND_PANEL_ABORT = Sound "moonpanel/panel_abort_tracing.ogg"
SOUND_POWER_ON = Sound "moonpanel/powered_on.ogg"
SOUND_POWER_OFF = Sound "moonpanel/powered_off.ogg"

circ = Material "moonpanel/circ128.png"
polyo = Material "moonpanel/polyomino_cell.png", "smooth"
vignette = Material "moonpanel/vignette.png"

COLOR_BLACK = Color 0, 0, 0, 255

setRTTexture = (rt) ->
    RT_Material\SetTexture "$basetexture", rt
    surface.SetMaterial RT_Material

gradient = (startColor, endColor, percentFade) ->
    diffRed = endColor.r - startColor.r
    diffGreen = endColor.g - startColor.g
    diffBlue = endColor.b - startColor.b
    diffAlpha = endColor.a - startColor.a

    return Color (diffRed * percentFade) + startColor.r,
        (diffGreen * percentFade) + startColor.g,
        (diffBlue * percentFade) + startColor.b,
        (diffAlpha * percentFade) + startColor.a

ENT.PanelInit = () =>
    index = tostring @EntIndex!
    @rendertargets = {
        foreground: {
            always: true
            rt: GetRenderTarget "TheMPFG#{index}", @ScreenSize, @ScreenSize
            render: @DrawForeground
        }
        background: {
            rt: GetRenderTarget "TheMPBG#{index}", @ScreenSize, @ScreenSize
            render: @DrawBackground
        }
        trace: {
            rt: GetRenderTarget "TheMPTrace#{index}", @ScreenSize, @ScreenSize
            render: @DrawTrace
        }
        ripple: {
            always: true
            rt: GetRenderTarget "TheMPRipple#{index}", @ScreenSize, @ScreenSize
            render: @DrawRipple
        }
    }

    Moonpanel\requestData @
    @__nextSyncAttempt = CurTime! + RESYNC_ATTEMPT_TIME
    @__powerStatePct = 0

_err = Color 255, 0, 0, 255
_errAlt = Color 0, 0, 0, 255

ENT.ErrorifyColor = (color, alternate) =>
    pctMod = 1
    if @__finishTime
        pctMod = 1 - ((CurTime! - (@__finishTime)) / REDOUT_TIME)

    clr = _err
    if color.r > 200 and color.b < 30 and color.g < 30
        clr = _errAlt

    time = CurTime!

    pct = ((math.cos math.rad time * 500) + 1) / 2

    if alternate
        pct = 1 - pct

    return gradient color, clr, pctMod * pct

ENT.CleanUp = () =>
    @redOut = nil
    @grayOut = nil
    @grayOutStart = nil

    timer.Remove @GetTimerName "redOut"
    timer.Remove @GetTimerName "grayOut"
    timer.Remove @GetTimerName "penFade"
    timer.Remove @GetTimerName "foreground"

    @rendertargets.foreground.always = false
    @rendertargets.foreground.dirty = true
    @rendertargets.trace.dirty = true

ENT.Desynchronize = () =>
    @CleanUp!
    @tileData = nil
    @synchronized = false

ENT.ClientThink = () =>
    if not @synchronized and CurTime! >= (@__nextSyncAttempt or 0)
        Moonpanel\requestData @
        @__nextSyncAttempt = CurTime! + RESYNC_ATTEMPT_TIME

    elseif @shouldRepaintTrace and CurTime! >= (@nextTraceRepaint or 0)
        @shouldRepaintTrace = false
        @nextTraceRepaint = CurTime! + 0.02

        @rendertargets.trace.dirty = true

    powerState = @synchronized and @GetNW2Bool "TheMP Powered"
    @__powerStatePct or= 0
    if powerState and @__powerStatePct < 1
        @__powerStatePct = math.min 1, @__powerStatePct + 0.02

    if not powerState and @__powerStatePct > 0
        @__powerStatePct = math.max 0, @__powerStatePct - 0.02

ENT.ClientTickrateThink = () =>
    if not @synchronized
        return
        
    activeUser = @GetNW2Entity "ActiveUser"
    if IsValid activeUser
        if @__scintPower and @__scintPower >= 0.15 and CurTime! >= @__nextscint
            @EmitSound SOUND_PANEL_SCINT, 75, 100, @__scintPower
            @__nextscint = CurTime! + 2
            @__scintPower *= 0.75
            @__firstscint = false

ENT.NW_OnPowered = (state) =>
    if @synchronized
        if state
            @EmitSound SOUND_POWER_ON
        else
            @pen.a = 0
            @CleanUp!
            @EmitSound SOUND_POWER_OFF

ENT.PuzzleStart = (nodeA, nodeB) =>
    if not @synchronized
        return

    tr = @colors.traced
    @pen = Color tr.r, tr.g, tr.b, tr.a or 255

    @EmitSound SOUND_PANEL_START

    @pathFinder\restart nodeA, nodeB
    @shouldRepaintTrace = true

    @__nextscint = CurTime! + 0.5
    @__firstscint = true
    @__scintPower = 1
    
    @CleanUp!

ENT.PenFade = (interval, clr, delta = 5) =>
    if clr
        @pen = Color clr.r, clr.g, clr.b, clr.a or 255

    timer.Create @GetTimerName("penFade"), interval, 0, () ->
        if not IsValid @
            return

        if @pen.a <= 0
            @pen.a = 0
            timer.Remove @GetTimerName "penFade"
            return

        @pen.a -= delta
        @shouldRepaintTrace = true

ENT.PenInterpolate = (interval, _from, to, delta = 0.015) =>
    @__penInterp = 0

    timer.Create @GetTimerName("penFade"), interval, 0, () ->
        if not IsValid @
            return

        if @__penInterp > 1
            @__penInterp = 1

        @pen = gradient _from, to, @__penInterp

        if @__penInterp == 1
            timer.Remove @GetTimerName "penFade"
            return

        @__penInterp += delta
        @shouldRepaintTrace = true

ENT.PuzzleFinish = (data) =>
    success = data.success or false
    aborted = data.aborted or false
    @redOut = data.redOut or {}
    _grayOut = data.grayOut or {}
    stacks = data.stacks or {}

    @pathFinder.cursors = data.cursors
    @pathFinder.nodeStacks = {}
    for _, inStack in pairs stacks 
        stack = {}
        @pathFinder.nodeStacks[#@pathFinder.nodeStacks + 1] = stack
        for _, i in pairs inStack
            stack[#stack + 1] = @pathFinder.nodeMap[i]

    @__scintPower = nil
    @__finishTime = CurTime!

    @rendertargets.foreground.always = true
    if not aborted
        timer.Create @GetTimerName("foreground"), REDOUT_TIME, 1, () ->
            if not @rendertargets or not IsValid @
                return
            @rendertargets.foreground.always = false
            @redOut = nil
            @rendertargets.foreground.dirty = true

    if success
        if _grayOut.grayedOut
            if not data.sync
                @EmitSound SOUND_PANEL_POTENTIAL_FAILURE

            _oldPen = ColorAlpha @pen, @pen.a or 255
            err = @colors.errored

            @PenFade 0.05, Color err.r, err.g, err.b, err.a or 255
            timer.Create @GetTimerName("grayOut"), 0.75, 1, () ->
                timer.Remove @GetTimerName "penFade"
                @redOut = nil
                @grayOut = _grayOut
                @grayOutStart = CurTime!
                @pen = _oldPen

                if not data.sync
                    @EmitSound SOUND_PANEL_ERASER
                    @EmitSound SOUND_PANEL_SUCCESS

                    if @colors.traced ~= @colors.finished
                        @PenInterpolate 0.01, @pen, @colors.finished
                else
                    @pen = ColorAlpha @colors.finished, @colors.finished.a or 255

        else
            if not data.sync
                @EmitSound SOUND_PANEL_SUCCESS
                if @colors.traced ~= @colors.finished
                    @PenInterpolate 0.01, @pen, @colors.finished
            else
                @pen = ColorAlpha @colors.finished, @colors.finished.a or 255

    elseif not aborted
        err = @colors.errored
        @pen = Color err.r, err.g, err.b, err.a or 255

        if _grayOut.grayedOut
            if not data.sync
                @EmitSound SOUND_PANEL_POTENTIAL_FAILURE

            timer.Create @GetTimerName("grayOut"), 0.75, 1, () ->
                @grayOut = _grayOut
                @grayOutStart = CurTime!

                @PenFade 0.05, Color err.r, err.g, err.b
                @EmitSound SOUND_PANEL_FAILURE

        else
            @PenFade 0.05, Color err.r, err.g, err.b
            if not data.sync
                @EmitSound SOUND_PANEL_FAILURE

    else
        if not data.sync and not data.forceFail
            @EmitSound SOUND_PANEL_ABORT

        if @pen
            if data.forceFail
                @pen.a = 0
            else
                @PenFade 0.05, Color @pen.r, @pen.g, @pen.b, @pen.a or 255
    
    @shouldRepaintTrace = true

ENT.SetupDataClient = (data) =>
    @CleanUp!

    defs = Moonpanel.DefaultColors
    
    newColors = {}
    for key, color in pairs @tileData.Colors
        newColors[key] = Color color.r, color.g, color.b, color.a or 255
    
    @tileData.Colors = newColors

    @colors            = {}
    @colors.background = @tileData.Colors.Background or defs.Background
    @colors.untraced   = @tileData.Colors.Untraced or defs.Untraced
    @colors.traced     = @tileData.Colors.Traced or defs.Traced
    @colors.vignette   = @tileData.Colors.Vignette or defs.Vignette
    @colors.errored    = @tileData.Colors.Errored or defs.Errored
    @colors.cell       = @tileData.Colors.Cell or defs.Cell
    @colors.finished   = @tileData.Colors.Finished or defs.Finished

    @SetBackgroundColor @colors.background

    tr = @colors.traced
    @pen = Color tr.r, tr.g, tr.b, tr.a or 255

    cellsW = @tileData.Tile.Width
    cellsH = @tileData.Tile.Height

    @startRipples = {}
    @endRipples = {}
    for j = 1, cellsH + 1
        for i = 1, cellsW + 1
            int = @elements.intersections[j][i]
            if int and int.entity
                if int.entity.type == Moonpanel.EntityTypes.Start
                    @startRipples[#@startRipples + 1] = int.entity.ripple

                if int.entity.type == Moonpanel.EntityTypes.End
                    @endRipples[#@endRipples + 1] = int.entity.ripple

    @synchronized = true

    if data.lastSolution
        data.lastSolution.sync = true
        data.lastSolution.stacks = data.stacks
        data.lastSolution.cursors = data.cursors
        @PuzzleFinish data.lastSolution
    
    else
        stacks = data.stacks or {}

        @pathFinder.cursors = data.cursors
        @pathFinder.nodeStacks = {}
        for _, inStack in pairs stacks 
            stack = {}
            @pathFinder.nodeStacks[#@pathFinder.nodeStacks + 1] = stack
            for _, i in pairs inStack
                stack[#stack + 1] = @pathFinder.nodeMap[i]

    timer.Simple 0.5, () ->
        if IsValid @
            @NW_OnPowered @GetNW2Bool("TheMP Powered")
            @SetNW2VarProxy "TheMP Powered", (_, _, _, state) ->
                @NW_OnPowered state

    @rendertargets.background.dirty = true
    @rendertargets.foreground.dirty = true
    @rendertargets.trace.dirty = true

ENT.DrawBackground = () =>
    Clear 0, 0, 0, 0
    ClearDepth!

    cellsW = @tileData.Tile.Width
    cellsH = @tileData.Tile.Height
    barWidth = @calculatedDimensions.barWidth
    barLength = @calculatedDimensions.barLength

    surface.SetDrawColor @colors.untraced
    draw.NoTexture!
    render.SetColorMaterial!

    for j = 1, cellsH + 1
        for i = 1, cellsW + 1
            toRender = {}
            if i <= cellsW and j <= cellsH
                toRender[#toRender + 1] = @elements.cells[j][i]
            
            for _, obj in pairs toRender
                if obj and not (obj.entity and obj.entity.overridesRender)
                    obj\render!

                if obj and obj.entity and obj.entity.background
                    obj\renderEntity!

    surface.SetDrawColor @colors.untraced
    draw.NoTexture!
    render.SetColorMaterial!

    for _, connection in pairs @pathMapConnections
        nodeA = connection.to
        nodeB = connection.from

        if not nodeA.break
            Moonpanel.render.drawCircle nodeA.screenX, nodeA.screenY, (nodeA.clickable and barWidth * 1.25 or barWidth / 2), @colors.untraced
        
        if not nodeB.break
            Moonpanel.render.drawCircle nodeB.screenX, nodeB.screenY, (nodeB.clickable and barWidth * 1.25 or barWidth / 2), @colors.untraced
        
        length = nil
        if nodeA.break
            length = barWidth / 2 + math.sqrt (nodeA.screenY - nodeB.screenY)^2 + (nodeA.screenX - nodeB.screenX)^2

        Moonpanel.render.drawThickLine nodeA.screenX, nodeA.screenY, 
            nodeB.screenX, nodeB.screenY, barWidth + 0.5, length
    
ENT.DrawForeground = () =>
    Clear 0, 0, 0, 0
    ClearDepth!

    grayOutAlpha = if @grayOut
        255 * math.EaseInOut (1 - (math.Clamp (CurTime!- @grayOutStart) / 2, 0, 0.6)), 0.1, 0.1

    for _, entity in pairs @elements.entities
        if entity.background
            continue

        clr = Moonpanel.Colors[(entity.attributes and entity.attributes.color) or 1]

        obj = entity.parent
        if grayOutAlpha and @grayOut[obj.type] and @grayOut[obj.type][obj.y] and @grayOut[obj.type][obj.y][obj.x]
            clr = ColorAlpha clr, grayOutAlpha

        elseif @redOut and @redOut[obj.type] and @redOut[obj.type][obj.y] and @redOut[obj.type][obj.y][obj.x]
            alternate = ((obj.y + obj.x) % 2 == 0) and true or false
            clr = @ErrorifyColor clr, alternate

        surface.SetDrawColor clr
        draw.NoTexture!
        render.SetColorMaterial!
        entity\render!

ENT.DrawTrace = () =>
    Clear 0, 0, 0, 0
    ClearDepth! 

    if false
        for _, node in pairs @pathMap
            w, h = 32, 32
            if node.clickable
                w, h = w * 2, h * 2
            x, y = node.screenX - w/2, node.screenY - w/2
            render.SetMaterial circ
            Moonpanel.render.drawTexturedRect x, y, w, h, (Color 255, 0, 0)
            render.SetColorMaterial!

            for _, neighbor in pairs node.neighbors
                draw.NoTexture!
                surface.SetDrawColor (Color 255, 0, 0, 255)
                surface.DrawLine node.screenX, node.screenY, neighbor.screenX, neighbor.screenY

    nodeStacks = @pathFinder.nodeStacks
    cursors = @pathFinder.cursors

    surface.SetDrawColor @colors.traced
    if nodeStacks
        barWidth = @calculatedDimensions.barWidth
        barLength = @calculatedDimensions.barLength
        symmVector = nil

        for stackId, stack in pairs nodeStacks 
            for k, v in pairs stack
                Moonpanel.render.drawCircle v.screenX, v.screenY, ((k == 1) and barWidth * 1.25 or barWidth / 2), @colors.traced

                if k > 1
                    prev = stack[k - 1]
                    Moonpanel.render.drawThickLine prev.screenX, prev.screenY, v.screenX, v.screenY, barWidth + 0.5

        if cursors and #cursors > 0
            for stackid, cur in pairs cursors
                stack = nodeStacks[stackid]
                last = stack[#stack]
                Moonpanel.render.drawCircle cur.x, cur.y, barWidth / 2, @colors.traced
                Moonpanel.render.drawThickLine cur.x, cur.y, last.screenX, last.screenY, barWidth + 0.5

ENT.DrawRipple = () =>
    Clear 0, 0, 0, 0
    ClearDepth!

    draw.NoTexture!
    render.SetColorMaterial!
    activeUser = @GetNW2Entity "ActiveUser"
    if @endRipples and @__nextscint and not @__firstscint and IsValid activeUser
        buf = 1 - ((@__nextscint - CurTime!) / 2)
        for _, ripple in pairs @endRipples
            Moonpanel.render.drawRipple ripple, buf, (Color 255, 255, 255)

renderFunc = (x, y, w, h) ->
    surface.DrawTexturedRect x, y, w, h

ENT.DrawLoading = (powerStatePct) =>
    draw.NoTexture!
    if not @colors or @colors.background.a ~= 0
        surface.SetDrawColor ColorAlpha COLOR_BLACK, (255 * powerStatePct)
        surface.DrawRect 0, 0, @ScreenSize, @ScreenSize

    if not @synchronized
        color = Color 255, 255, 255
        width = @ScreenSize * 0.1
        num = 4
        step = (math.pi) / num
        spacing = width * 0.4

        totalWidth = width * num + spacing * (num - 1)
        surface.SetMaterial polyo
        for i = 0, num - 1
            pct = ((1 + (math.sin CurTime! * 2.5 - i * step)) / 2) 
            surface.SetDrawColor ColorAlpha color, (255 * (1-pct)) * powerStatePct
            surface.DrawTexturedRect (@ScreenSize / 2) - (totalWidth / 2) + (i * width) + (i * spacing),
                (@ScreenSize / 2) - (width / 2), width, width

ENT.RenderPanel = () =>
    if not @synchronized or @__powerStatePct == 0
        @DrawLoading 1 - @__powerStatePct
        return

    shouldRender = @synchronized and @rendertargets and @calculatedDimensions
    if shouldRender
        oldw, oldh = ScrW!, ScrH!
        for k, v in pairs @rendertargets
            if (v.always or v.dirty ~= false) and v.render
                v.dirty = false

                SetStencilEnable false
                SetViewPort 0, 0, @ScreenSize, @ScreenSize
                cam.Start2D!

                draw.NoTexture!
                SetColorMaterial!

                PushRenderTarget v.rt
                v.render @
                PopRenderTarget!

                cam.End2D!
                SetViewPort 0, 0, oldw, oldh
                SetStencilEnable true

    surface.SetDrawColor (@colors and @colors.vignette) or Moonpanel.DefaultColors.Vignette
    surface.SetMaterial vignette
    surface.DrawTexturedRect 0, 0, @ScreenSize, @ScreenSize

    if shouldRender
        SetDrawColor 255, 255, 255, 255 * @__powerStatePct
        setRTTexture @rendertargets.background.rt
        renderFunc 0, 0, @ScreenSize, @ScreenSize

        setRTTexture @rendertargets.foreground.rt
        renderFunc 0, 0, @ScreenSize, @ScreenSize

        setRTTexture @rendertargets.ripple.rt
        renderFunc 0, 0, @ScreenSize, @ScreenSize

        surface.SetDrawColor @pen
        setRTTexture @rendertargets.trace.rt
        renderFunc 0, 0, @ScreenSize, @ScreenSize

    if @__powerStatePct ~= 1
        @DrawLoading 1 - @__powerStatePct
