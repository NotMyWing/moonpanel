import SetDrawColor, DrawRect from surface
import Clear, ClearDepth, OverrideAlphaWriteEnable from render
import SetStencilEnable, SetViewPort, SetColorMaterial, PushRenderTarget, PopRenderTarget from render
import sCurve, sCurveGradient, gradient, colorCopy from Moonpanel.render

colorsEqual = (a, b) ->
    return (a and b) and (a.r == b.r and a.g == b.g and a.b == b.b and a.a == b.a) or false

ENT.ResetTraceInterps = =>
    @__interps = {}
    for i = 1, (@tileData.Symmetry.Type ~= 0) and 2 or 1
        @__interps[i] = colorCopy @__startColors[i]

ENT.TraceInterpolate = (id, _from = nil, to, callback, mod = nil, sCurve = true) =>
    with @__interps[id]
        .finished = false
        .sCurve   = sCurve
        .callback = callback
        .from     = _from or colorCopy @__interps[id]
        .to       = to
        .mod      = mod or 1
        .acc      = 0

ENT.TraceInterpolateThink = (delta) =>
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

ENT.DrawTrace = () =>
    Clear 0, 0, 0, 0
    ClearDepth!

    if not @__branchAnimators
        return

    --
    -- Rather complicated way to make traces disappear.
    --
    if @__finishTime and (@__traceAlphaGrayingOut or not @__isSolutionSuccessful) and @__traceAlpha > 0
        @rendertargets.trace.dirty = true
        @__traceAlpha -= FrameTime! * (300 * @__traceAlphaFadeMod)
        if @__traceAlpha < 0
            @__traceAlpha = 0

    --
    -- Rather complicated way to make start nodes grow in size.
    --
    if @__penSizeModifier
        @__penSizeModifier += math.max 0.001, FrameTime! * 5
        if @__penSizeModifier > 1
            @__penSizeModifier = 1
        elseif @__penSizeModifier < 1
            @rendertargets.trace.dirty = true


    circle   = @calculatedDimensions.barCircle
    barWidth = @calculatedDimensions.barWidth

    draw.NoTexture!

    for stackId, animator in ipairs @__branchAnimators
        --
        -- Skip drawing the trace if it's invisible.
        --
        if @tileData.Symmetry.Colorful and @tileData.Symmetry.Traces[stackId].Invisible
            continue

        interp = @__interps[stackId]
        if not interp
            break

        local newPenColor 
        
        shouldBlink = not @__finishTime and @__touchingExit

        --
        -- Rather complicated way to make traces blink.
        --
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
                @TraceInterpolate stackId, nil, newClr, nil, (@__lastShouldBlink[stackId]) and 5 or 20, false

        elseif not @__finishTime
            --
            -- Behold, the clusterfuck of binary operators.
            --
            newPenColor = @__startColors[stackId]
            if newPenColor
                if (newPenColor.r ~= interp.r or newPenColor.g ~= interp.g or newPenColor.b ~= interp.b) and
                    (not interp.to or (
                        newPenColor.r ~= interp.to.r or newPenColor.g ~= interp.to.g or newPenColor.b ~= interp.to.b
                    ))
                    @TraceInterpolate stackId, nil, newPenColor, nil, 1, true

        @__lastShouldBlink[stackId] = shouldBlink

        with interp
            surface.SetDrawColor .r, .g, .b, 255

        changed = animator\think!
        if changed 
            @rendertargets.trace.dirty = true

        buffer = animator\getPosition!

        --
        -- Draw the starting node.
        --
        Moonpanel.render.drawCircleAt @calculatedDimensions.startCircle,
            animator.__nodeStack[1].x,
            animator.__nodeStack[1].y,
            @__penSizeModifier

        --
        -- While the buffer is more than zero, draw the trace.
        --
        if buffer > 0
            target = animator\getBranchNode! or animator\getLastNode!

            for i = 1, target.id - 1
                current = animator.__nodeStack[i]
                next    = animator.__nodeStack[i + 1]
                
                mag = math.min buffer, next.totalLength and current.totalLength and (next.totalLength - current.totalLength) or 0

                buffer -= mag

                Moonpanel.render.drawThickLine next.x, next.y, 
                    current.x, current.y, barWidth + 0.5, mag

                -- Draw the circly circle.
                do
                    dx = next.x - current.x
                    dy = next.y - current.y

                    _mag = math.sqrt dx^2 + dy^2
                    dx = dx / _mag * mag
                    dy = dy / _mag * mag

                    Moonpanel.render.drawCircleAt circle, current.x + dx, current.y + dy, 1

                if buffer <= 0
                    break

            --
            -- Draw the auxiliary trace. The one that backtracks.
            --
            if buffer > 0 and animator.__auxiliaryStack[1]
                branchnode = animator\getBranchNode! or animator.__nodeStack[#animator.__nodeStack]
                
                for i = 1, #animator.__auxiliaryStack
                    current = animator.__auxiliaryStack[i - 1] or branchnode
                    next    = animator.__auxiliaryStack[i]

                    mag = math.min buffer, next.totalLength and current.totalLength and (next.totalLength - current.totalLength) or 0

                    buffer -= mag

                    Moonpanel.render.drawThickLine next.x, next.y, 
                        current.x, current.y, barWidth + 0.5, mag

                    -- Circle 2: Electric Boogaloo.
                    do
                        dx = next.x - current.x
                        dy = next.y - current.y

                        _mag = math.sqrt dx^2 + dy^2
                        dx = dx / _mag * mag
                        dy = dy / _mag * mag

                        Moonpanel.render.drawCircleAt circle, current.x + dx, current.y + dy

                    if buffer <= 0
                        break

ENT.UpdateTraceCursor = (cursor) =>
    if @__branchAnimators
        for _, animator in ipairs @__branchAnimators
            animator\setCursor cursor
        @rendertargets.trace.dirty = true

ENT.TracePotentialNode = (id, screenX, screenY) =>
    animator = @__branchAnimators[id]
    if animator
        if animator.__ignoreNextPotential
            animator.__ignoreNextPotential = false
            return

        last = animator\getLastNode!

        if last.x ~= screenX or last.y ~= screenY
            if animator\getLastNode!.__potential
                animator\popNode!

            with animator\pushNode screenX, screenY
                .__potential = true

ENT.TracePushNode = (id, screenX, screenY) =>
    animator = @__branchAnimators[id]
    if animator
        last = animator\getLastNode!
        if last and last.__potential
            if last.x == screenX and last.y == screenY
                last.__potential = false
            else
                animator\popNode!
                animator\pushNode screenX, screenY
        else
            animator\pushNode screenX, screenY

        animator\setCursor 1

        @rendertargets.trace.dirty = true

ENT.TracePopNode = (id) =>
    animator = @__branchAnimators[id]
    if animator
        last = animator\getLastNode!
        if last.__potential
            animator\popNode!
            animator.__ignoreNextPotential = true

        animator\getLastNode!.__potential = true

        @rendertargets.trace.dirty = true

ENT.UpdateTouchingExit = (state) =>
    if @__touchingExit ~= state
        @__touchingExit = state

        if @sounds.finishTracing and state
            @PlaySound @sounds.finishTracing

            if @__shouldScint
                @__shouldScint = false

            if not @sounds.pathComplete\IsPlaying!
                @sounds.pathComplete\Play!

        elseif @sounds.abortFinishTracing and not state
            if not @__finishTime
                @PlaySound @sounds.abortFinishTracing

            if @sounds.pathComplete\IsPlaying!
                @sounds.pathComplete\Stop!
