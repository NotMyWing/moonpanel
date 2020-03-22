import SetDrawColor, DrawRect from surface
import Clear, ClearDepth, OverrideAlphaWriteEnable from render
import SetStencilEnable, SetViewPort, SetColorMaterial, PushRenderTarget, PopRenderTarget from render
import sCurve, sCurveGradient, gradient, colorCopy from Moonpanel.render

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

polyo = Material "moonpanel/common/polyomino_cell.png", "smooth"
vignette = Material "moonpanel/common/vignette.png"

COLOR_BLACK = Color 0, 0, 0, 255

TraceState = {
    None: 0
    Errored: 1
    GrayOut: 2
    FadeIn: 3
    FadeOut: 4
}

colorsEqual = (a, b) ->
    return (a and b) and (a.r == b.r and a.g == b.g and a.b == b.b and a.a == b.a) or false

blinkifyColor = (color, forcePositive) ->
    h, s, v = color\ToHSV!

    mod = 0.1
    HSVToColor h, s, (forcePositive or (v + mod <= 1)) and (math.min 1, v + mod) or (v - mod)

setRTTexture = (rt) ->
    RT_Material\SetTexture "$basetexture", rt
    surface.SetMaterial RT_Material

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
            rt: GetRenderTarget "TheMPRipple#{index}", @ScreenSize, @ScreenSize
            render: @DrawRipple
        }
    }

    Moonpanel\requestData @
    @__nextSyncAttempt = CurTime! + RESYNC_ATTEMPT_TIME
    @__powerStatePct = 0

    panelSoundLevel = 65
    @sounds = {
        scint:    with CreateSound @, "moonpanel/panel_scint.ogg"
            \SetSoundLevel panelSoundLevel

        failure:  with CreateSound @, "moonpanel/panel_failure.ogg"
            \SetSoundLevel panelSoundLevel

        potentialFailure: with CreateSound @, "moonpanel/panel_potential_failure.ogg"
            \SetSoundLevel panelSoundLevel

        success:  with CreateSound @, "moonpanel/panel_success.ogg"
            \SetSoundLevel panelSoundLevel

        start:    with CreateSound @, "moonpanel/panel_start_tracing.ogg"
            \SetSoundLevel panelSoundLevel

        eraser:   with CreateSound @, "moonpanel/eraser_apply.ogg"
            \SetSoundLevel panelSoundLevel
            
        abort:    with CreateSound @, "moonpanel/panel_abort_tracing.ogg"
            \SetSoundLevel panelSoundLevel

        powerOn:  with CreateSound @, "moonpanel/powered_on.ogg"
            \SetSoundLevel panelSoundLevel

        powerOff: with CreateSound @, "moonpanel/powered_off.ogg"
            \SetSoundLevel panelSoundLevel

        pathComplete: with CreateSound @, "moonpanel/panel_path_complete_loop.wav"
            \SetSoundLevel 45

        solvingLoop: with CreateSound @, "moonpanel/panel_solving_loop.wav"
            \SetSoundLevel 40

        presenceLoop: with CreateSound @, "moonpanel/panel_presence_loop.wav"
            \SetSoundLevel 40

        finishTracing: with CreateSound @, "moonpanel/panel_finish_tracing.ogg"
            \SetSoundLevel panelSoundLevel

        abortFinishTracing: with CreateSound @, "moonpanel/panel_abort_finish_tracing.ogg"
            \SetSoundLevel panelSoundLevel
    }

ENT.OnRemove = () =>
    for i, sound in pairs @sounds
        if sound\IsPlaying!
            sound\Stop!
            @sounds[i] = nil

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
    if @sounds
        if @sounds.pathComplete\IsPlaying!
            @sounds.pathComplete\Stop!
        
        if @sounds.solvingLoop\IsPlaying!
            @sounds.solvingLoop\Stop!    

    @redOut = nil
    @grayOut = nil
    @grayOutStart = nil
    @__finishTime = nil
    @__isSolutionAborted = false
    @__isSolutionSuccessful = false
    @__traceLerps or= {}
    table.Empty @__traceLerps

    timer.Remove @GetTimerName "grayOut"
    timer.Remove @GetTimerName "foreground"

    if @rendertargets
        @rendertargets.foreground.always = false
        @rendertargets.foreground.dirty = true
        @rendertargets.trace.dirty = true

    @__lastShouldBlink = {}
    @__traceAlpha      = 0
    @__traceState      = TraceState.None
    
    if @colors
        @ResetInterps!

ENT.ResetInterps = =>
    @__interps = {}
    for i = 1, (@tileData.Symmetry.Type ~= 0) and 2 or 1
        @__interps[i] = colorCopy @__startColors[i]

ENT.Interpolate = (id, _from = nil, to, callback, mod = nil, sCurve = true) =>
    with @__interps[id]
        .finished = false
        .sCurve   = sCurve
        .callback = callback
        .from     = _from or colorCopy @__interps[id]
        .to       = to
        .mod      = mod or 1
        .acc      = 0

ENT.InterpolateThink = (delta) =>
    if not @__interps
        return

    dirty = false
    for i = 1, (@tileData.Symmetry.Type ~= 0) and 2 or 1
        with @__interps[i]
            if .finished == false
                dirty = true
                .acc += delta * .mod

                if .acc >= 1
                    .acc = 1
                    .finished = true

                func = .sCurve and sCurveGradient or gradient
                .r, .g, .b, .a = func .from, .to, .acc

                if .finished
                    if .callback
                        .callback!

    if dirty
        @rendertargets.trace.dirty = true

ENT.Desynchronize = () =>
    @CleanUp!
    @tileData = nil
    @synchronized = false

ENT.ClientThink = () =>
    @__activeUser = @GetNW2Entity "ActiveUser"

    if not @synchronized and CurTime! >= (@__nextSyncAttempt or 0)
        Moonpanel\requestData @
        @__nextSyncAttempt = CurTime! + RESYNC_ATTEMPT_TIME

    powerState = @synchronized and @GetNW2Bool "TheMP Powered"
    @__powerStatePct or= 0
    if powerState and @__powerStatePct < 1
        @__powerStatePct = math.min 1, @__powerStatePct + 0.02

    if not powerState and @__powerStatePct > 0
        @__powerStatePct = math.max 0, @__powerStatePct - 0.02

ENT.ClientTickrateThink = () =>
    if not @synchronized
        return
        
    activeUser = @__activeUser
    if IsValid activeUser
        if @__shouldScint and @__scintPower and @__scintPower >= 0.15 and CurTime! >= @__nextscint
            if @sounds.scint
                @sounds.scint\Stop!
                @sounds.scint\PlayEx @__scintPower, 100

            @__nextscint = CurTime! + 2
            @__scintPower *= 0.75
            @__firstscint = false

ENT.NW_OnPowered = (state) =>
    if @synchronized
        if state
            if @sounds.presenceLoop
                @sounds.presenceLoop\Play!

            if @sounds.powerOn
                @PlaySound @sounds.powerOn
        else
            @CleanUp!
            if @sounds.presenceLoop
                @sounds.presenceLoop\Stop!

            if @sounds.powerOff
                @PlaySound @sounds.powerOff

ENT.PuzzleStart = (nodeA, nodeB) =>
    if not @synchronized
        return

    @CleanUp!
    if @sounds.start
        @PlaySound @sounds.start

    if @sounds.presenceLoop
        if not @sounds.presenceLoop\IsPlaying!
            @sounds.presenceLoop\PlayEx 1, 100

        @sounds.presenceLoop\ChangeVolume 0, 5

    if @sounds.solvingLoop
        if not @sounds.solvingLoop\IsPlaying!
            @sounds.solvingLoop\PlayEx 0, 100

        @sounds.solvingLoop\ChangeVolume 1, 0.25

    @pathFinder\restart nodeA, nodeB
    @rendertargets.trace.dirty = true

    @__nextscint = CurTime! + 0.5
    @__firstscint = true
    @__shouldScint = true
    @__scintPower = 1

    barWidth = @calculatedDimensions.barWidth
    @__penSizeModifier = (barWidth / 2) / (barWidth * 1.25)

    @__traceAlpha           = 255
    @__traceAlphaFadeMod    = 1
    @__traceAlphaGrayingOut = false

ENT.BlinkFinish = =>
    for i = 1, (@tileData.Symmetry.Type ~= 0) and 2 or 1
        callback = () ->
            @Interpolate i, nil, @__endColors[i], nil, 4

        @Interpolate i, nil, @__fadeInOutColors[i], callback, 4

ENT.PuzzleFinish = (data) =>
    if @sounds.pathComplete and @sounds.pathComplete\IsPlaying!
        @sounds.pathComplete\Stop!

    if @sounds.solvingLoop
        if not @sounds.solvingLoop\IsPlaying!
            @sounds.solvingLoop\PlayEx 1, 100

        @sounds.solvingLoop\ChangeVolume 0, 0.25

    if @sounds.presenceLoop
        if not @sounds.presenceLoop\IsPlaying!
            @sounds.presenceLoop\PlayEx 0, 100

        @sounds.presenceLoop\ChangeVolume 1, 1

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

    if not aborted
        @rendertargets.foreground.always = true
        timer.Create @GetTimerName("foreground"), REDOUT_TIME, 1, () ->
            if not @rendertargets or not IsValid @
                return

            @rendertargets.foreground.always = false
            @redOut = nil
            @rendertargets.foreground.dirty = true

    if success
        if _grayOut.grayedOut
            if @sounds.potentialFailure
                @PlaySound @sounds.potentialFailure

            for i = 1, (@tileData.Symmetry.Type ~= 0) and 2 or 1
                @Interpolate i, nil, @colors.errored, nil, 10000
                @__traceAlphaFadeMod = 0.1
                @__traceAlphaGrayingOut = true

            timer.Create @GetTimerName("grayOut"), 0.75, 1, () ->
                if not @rendertargets or not IsValid @
                    return

                @redOut = nil
                @grayOut = _grayOut
                @grayOutStart = CurTime!
                @__traceAlphaGrayingOut = false
                @__traceAlpha = 255

                @BlinkFinish!

                if not data.sync
                    if @sounds.eraser
                        @PlaySound @sounds.eraser
                    if @sounds.success
                        @PlaySound @sounds.success
                
                @__traceState = TraceState.FadeOut

        else
            @BlinkFinish!
            if not data.sync
                if @sounds.success
                    @PlaySound @sounds.success

    elseif not aborted
        if _grayOut.grayedOut
            if not data.sync and @sounds.potentialFailure
                @PlaySound @sounds.potentialFailure

            @__traceAlphaFadeMod = 0.1
            timer.Create @GetTimerName("grayOut"), 0.75, 1, () ->
                if not @rendertargets or not IsValid @
                    return

                @grayOut = _grayOut
                @grayOutStart = CurTime!
                @__traceAlphaFadeMod = 1

                if not data.sync and @sounds.failure
                    @PlaySound @sounds.failure

        else
            @__traceAlphaFadeMod = 0
            fired = false

            for i = 1, (@tileData.Symmetry.Type ~= 0) and 2 or 1
                callback = () ->
                    if not fired
                        fired = true
                        @__traceAlphaFadeMod = 1

                    @Interpolate i, nil, @colors.errored, nil, 10000

                @Interpolate i, nil, @__startColors[i], callback, 10000
                
            if not data.sync and @sounds.failure
                @PlaySound @sounds.failure

    else
        if not data.sync and not data.forceFail and @sounds.abort
            @PlaySound @sounds.abort

    @__isSolutionAborted = aborted
    @__isSolutionSuccessful = success
    @rendertargets.trace.dirty = true

ENT.PlaySound = (sound) =>
    sound\Stop!
    sound\Play!

ENT.SetupDataClient = (data) =>
    @CleanUp!

    defs = Moonpanel.DefaultColors
    
    newColors = {}
    for key, color in pairs @tileData.Colors
        newColors[key] = Color color.r, color.g, color.b, color.a or 255
    
    @tileData.Colors = newColors

    @colors            = {}
    @colors.background = @tileData.Colors.Background or defs.Background
    @colors.untraced   = @tileData.Colors.Untraced   or defs.Untraced
    @colors.traced     = @tileData.Colors.Traced     or defs.Traced
    @colors.vignette   = @tileData.Colors.Vignette   or defs.Vignette
    @colors.errored    = @tileData.Colors.Errored    or defs.Errored
    @colors.cell       = @tileData.Colors.Cell       or defs.Cell
    @colors.finished   = @tileData.Colors.Finished   or defs.Finished

    @SetBackgroundColor @colors.background

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

    isColorful = (@tileData.Symmetry.Type ~= 0) and @tileData.Symmetry.Colorful

    @__startColors     = {}
    @__endColors       = {}
    @__blinkColors     = {}
    @__fadeInOutColors = {}

    for i = 1, (@tileData.Symmetry.Type ~= 0) and 2 or 1
        table.insert @__startColors, colorCopy (
            isColorful and Moonpanel.Colors[@tileData.Symmetry.Traces[i].Color or
                Moonpanel.ColorfulSymmetryDefaultColors[i]] or @colors.traced
        )

        table.insert @__endColors, colorCopy (
            isColorful and Moonpanel.ColorfulSymmetryEndColors[@tileData.Symmetry.Traces[i].Color] or 
                @colors.finished
        )

        table.insert @__blinkColors, blinkifyColor (
            isColorful and Moonpanel.Colors[@tileData.Symmetry.Traces[i].Color or
                Moonpanel.ColorfulSymmetryDefaultColors[i]] or @colors.traced
        )
        
        table.insert @__fadeInOutColors, blinkifyColor (
            isColorful and Moonpanel.Colors[@tileData.Symmetry.Traces[i].Color or
                Moonpanel.ColorfulSymmetryDefaultColors[i]] or @colors.traced
        ), true

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

    barCircle = @calculatedDimensions.barCircle
    startCircle = @calculatedDimensions.startCircle

    seen = {}
    for _, connection in pairs @pathMapConnections
        nodeA = connection.to
        nodeB = connection.from

        if not nodeA.break and not seen[nodeA]
            Moonpanel.render.drawCircleAt nodeA.clickable and startCircle or barCircle, nodeA.screenX, nodeA.screenY

        if not nodeB.break and not seen[nodeB]
            Moonpanel.render.drawCircleAt nodeB.clickable and startCircle or barCircle, nodeB.screenX, nodeB.screenY

        length = nil
        if nodeA.break
            length = barWidth / 2 + math.sqrt (nodeA.screenY - nodeB.screenY)^2 + (nodeA.screenX - nodeB.screenX)^2

        Moonpanel.render.drawThickLine nodeA.screenX, nodeA.screenY, 
            nodeB.screenX, nodeB.screenY, barWidth + 0.5, length

        seen[nodeA] = true
        seen[nodeB] = true

    for _, node in pairs @pathMapDisconnectedNodes
        Moonpanel.render.drawCircleAt node.clickable and startCircle or barCircle, node.screenX, node.screenY
    
ENT.DrawForeground = () =>
    Clear 0, 0, 0, 0
    ClearDepth!

    grayOutAlpha = if @grayOut
        255 * math.EaseInOut (1 - (math.Clamp (CurTime!- @grayOutStart) / 3, 0, 0.625)), 0.1, 0.1

    for _, entity in pairs @elements.entities
        if entity.background
            continue

        clr = Moonpanel.Colors[(entity.attributes and entity.attributes.color) or 1]

        obj = entity.parent
        if grayOutAlpha and @grayOut[obj.type] and @grayOut[obj.type][obj.y] and @grayOut[obj.type][obj.y][obj.x]
            surface.SetDrawColor clr.r, clr.g, clr.b, grayOutAlpha

        elseif @redOut and @redOut[obj.type] and @redOut[obj.type][obj.y] and @redOut[obj.type][obj.y][obj.x]
            alternate = ((obj.y + obj.x) % 2 == 0) and true or false
            surface.SetDrawColor @ErrorifyColor clr, alternate

        else
            surface.SetDrawColor clr

        draw.NoTexture!
        render.SetColorMaterial!
        entity\render!

ENT.CalculateLineLength = (stackId) =>
    if @__calculatedLineLength and @__calculatedLineLength[stack]
        return @__calculatedLineLength[stack]

    cursor = @pathFinder.cursors[stackId]
    stack = @pathFinder.nodeStacks[stackId]

    local cursorNode
    if not @__finishTime or @__isSolutionAborted
        cursorNode = {
            screenX: cursor.x
            screenY: cursor.y
        }

        table.insert stack, cursorNode

    stackLength = #stack
    cursor = cursor
    last = stack[#stack]

    length = 0
    for nodeId, node in pairs stack
        if nodeId == 1
            continue

        prev = stack[nodeId - 1]
        delta = math.sqrt (prev.screenX - node.screenX)^2 + (prev.screenY - node.screenY)^2
        
        prev.__delta = delta
        length += delta

    if cursorNode
        table.remove stack, #stack

    return length

ENT.DrawTrace = () =>
    Clear 0, 0, 0, 0
    ClearDepth!

    draw.NoTexture!

    if false
        for _, node in pairs @pathMap
            if node.hili
                surface.SetDrawColor (Color 0, 255, 255, 255)
            else
                surface.SetDrawColor (Color 255, 0, 0, 255)

            w, h = 32, 32
            if node.clickable
                w, h = w * 2, h * 2
            x, y = node.screenX - w/2, node.screenY - w/2
            Moonpanel.render.drawCircleAt @calculatedDimensions.barCircle, node.screenX, node.screenY, 0.5

            surface.SetDrawColor (Color 255, 0, 0, 255)
            for _, neighbor in pairs node.neighbors
                surface.DrawLine node.screenX, node.screenY, neighbor.screenX, neighbor.screenY

    nodeStacks = @pathFinder.nodeStacks
    cursors = @pathFinder.cursors

    barWidth = @calculatedDimensions.barWidth
    if nodeStacks and #nodeStacks > 0
        if @__finishTime and (@__traceAlphaGrayingOut or not @__isSolutionSuccessful) and @__traceAlpha > 0
            @rendertargets.trace.dirty = true
            @__traceAlpha -= FrameTime! * (300 * @__traceAlphaFadeMod)
            if @__traceAlpha < 0
                @__traceAlpha = 0

        if @__penSizeModifier
            @__penSizeModifier += math.max 0.001, FrameTime! * 5
            if @__penSizeModifier > 1
                @__penSizeModifier = 1
            elseif @__penSizeModifier < 1
                @rendertargets.trace.dirty = true

        for stackId, stack in pairs nodeStacks
            interp = @__interps[stackId]
            if not interp
                return
                
            interpMod = 1
            sCurve = true

            local newPenColor 
            
            shouldBlink = not @__finishTime and (stack[#stack].exit or 
                @pathFinder.potentialNodes[stackId] and @pathFinder.potentialNodes[stackId].exit)
        
            if stackId == 1 and @__lastShouldBlink[stackId] ~= shouldBlink
                if @sounds.finishTracing and shouldBlink
                    @PlaySound @sounds.finishTracing
                    if @__shouldScint
                        @__shouldScint = false
                    if not @sounds.pathComplete\IsPlaying!
                        @sounds.pathComplete\Play!
                elseif @sounds.abortFinishTracing and not shouldBlink
                    if not @__finishTime
                        @PlaySound @sounds.abortFinishTracing
                    if @sounds.pathComplete\IsPlaying!
                        @sounds.pathComplete\Stop!

            if shouldBlink
                @rendertargets.trace.dirty = true
                isHeadingToA = colorsEqual interp.to, @__blinkColors[stackId]
                isHeadingToB = colorsEqual interp.to, @__startColors[stackId]

                local newClr
                if (not @__lastShouldBlink[stackId]) or (isHeadingToA and interp.finished)
                    newClr = @__startColors[stackId]
                elseif isHeadingToB and interp.finished
                    newClr = @__blinkColors[stackId] 

                if newClr
                    @Interpolate stackId, nil, newClr, nil, (@__lastShouldBlink[stackId]) and 5 or 20, false

            elseif not @__finishTime
                newPenColor = @__startColors[stackId]

            @__lastShouldBlink[stackId] = shouldBlink

            if newPenColor
                if (newPenColor.r ~= interp.r or newPenColor.g ~= interp.g or newPenColor.b ~= interp.b) and
                    (not interp.to or (
                        newPenColor.r ~= interp.to.r or newPenColor.g ~= interp.to.g or newPenColor.b ~= interp.to.b
                    ))
                    @Interpolate stackId, nil, newPenColor, nil, interpMod, sCurve

            if @tileData.Symmetry.Colorful and @tileData.Symmetry.Traces[stackId].Invisible
                continue

            with interp
                surface.SetDrawColor .r, .g, .b, 255

            cursor = cursors[stackId]
            length = @CalculateLineLength stackId

            @__traceLerps[stackId] or= 0
            lerped = @__traceLerps[stackId]
            if lerped ~= length
                @rendertargets.trace.dirty = true

                lerped = math.Approach lerped, length, math.max 1, math.abs(lerped - length) * math.max 0.01, FrameTime! * 25
                @__traceLerps[stackId] = lerped

            local cursorNode
            if not @__finishTime or @__isSolutionAborted
                cursorNode = {
                    screenX: cursor.x
                    screenY: cursor.y
                }

                table.insert stack, cursorNode

            accumulator = 0
            for nodeId, node in pairs stack
                delta = node.__delta

                circ = nodeId == 1 and @calculatedDimensions.startCircle or @calculatedDimensions.barCircle
                scale = nodeId == 1 and @__penSizeModifier or 1
                Moonpanel.render.drawCircleAt circ, node.screenX, node.screenY, scale

                next = stack[nodeId + 1]
                if not next
                    break

                if accumulator + delta <= lerped
                    accumulator += delta
                    
                    Moonpanel.render.drawThickLine node.screenX, node.screenY, next.screenX, next.screenY, barWidth + 0.5
                    continue
                else
                    delta = lerped - accumulator
                    
                    dx = next.screenX - node.screenX
                    dy = next.screenY - node.screenY
                    mag = math.sqrt dx^2 + dy^2
                    dx = dx / mag * delta
                    dy = dy / mag * delta

                    Moonpanel.render.drawThickLine node.screenX, node.screenY, dx + node.screenX, dy + node.screenY, barWidth + 0.5
                    Moonpanel.render.drawCircleAt @calculatedDimensions.barCircle, dx + node.screenX, dy + node.screenY
                    break

            if cursorNode
                table.remove stack, #stack

ENT.DrawRipple = () =>
    Clear 0, 0, 0, 0
    ClearDepth!

    if @__shouldScint and @endRipples and @__nextscint and not @__firstscint and IsValid @__activeUser
        draw.NoTexture!
        render.SetColorMaterial!
    
        buf = 1 - ((@__nextscint - CurTime!) / 2)
        for _, ripple in pairs @endRipples
            Moonpanel.render.drawRipple ripple, buf * 2, (Color 255, 255, 255)

renderFunc = (x, y, w, h) ->
    surface.DrawTexturedRect x, y, w, h

ENT.DrawLoading = (powerStatePct) =>
    draw.NoTexture!
    if not @colors or @colors.background.a ~= 0
        surface.SetDrawColor COLOR_BLACK.r, COLOR_BLACK.g, COLOR_BLACK.b, (255 * powerStatePct)
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
            surface.SetDrawColor color.r, color.g, color.b, (255 * (1-pct)) * powerStatePct
            surface.DrawTexturedRect (@ScreenSize / 2) - (totalWidth / 2) + (i * width) + (i * spacing),
                (@ScreenSize / 2) - (width / 2), width, width

ENT.RenderPanel = () =>
    if not @synchronized or @__powerStatePct == 0
        @DrawLoading 1 - @__powerStatePct
        return

    shouldRender = @synchronized and @rendertargets and @calculatedDimensions
    if shouldRender
        @InterpolateThink FrameTime!

        if IsValid @__activeUser
            @rendertargets.ripple.dirty = true

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

        SetDrawColor 255, 255, 255, @colors.untraced.a * @__powerStatePct
        setRTTexture @rendertargets.foreground.rt
        renderFunc 0, 0, @ScreenSize, @ScreenSize

        SetDrawColor 255, 255, 255, 255 * @__powerStatePct
        setRTTexture @rendertargets.ripple.rt
        renderFunc 0, 0, @ScreenSize, @ScreenSize

        surface.SetDrawColor 255, 255, 255, @__traceAlpha
        setRTTexture @rendertargets.trace.rt
        renderFunc 0, 0, @ScreenSize, @ScreenSize

    if @__powerStatePct ~= 1
        @DrawLoading 1 - @__powerStatePct
