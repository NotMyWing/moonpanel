include "shared.lua"

ENT.InitializeSided = () =>
    info = Moonpanel.Canvas.ResolveScreenInfo @, @GetModel!
    @ScreenMatrix = Moonpanel.Canvas.BuildScreenMatrix info
    @Aspect = info.RatioX
    @Scale = info.RS
    @Origin = info.offset

	w, h = @GetResolution!
	self.ScreenQuad = {
        Vector(0, 0, 0)
        Vector(w, 0, 0)
        Vector(w, h, 0)
        Vector(0, h, 0)
    }

	@__lastFrameNumber = 0

    Moonpanel.Net.PanelRequestData @

surface.CreateFont "TheMP",
	font: "Roboto"
	extended: false
	size: 160

renderFunc = =>
    if @__canvas
		@__canvas\Paint Moonpanel.Canvas.Resolution,
			Moonpanel.Canvas.Resolution

errorFunc = (err) ->
    print "Rendering error: #{err}"
    print debug.traceback!

ENT.Draw = () =>

ENT.DrawTranslucent = =>
    @DrawModel!

    return if not @ScreenMatrix

    @Transform = @GetBoneMatrix(0) * @ScreenMatrix

    if not @__canvas\CanRender!
        @__rendering = false

    if not @__rendering and @__canvas\AllocateRT!
        @__rendering = true

    return if not @__rendering

    @__lastFrameNumber = FrameNumber!

    -- Tone down HDR
    old = render.GetToneMappingScaleLinear!
    render.SetToneMappingScaleLinear old * 0.75

    cam.PushModelMatrix @Transform
    xpcall renderFunc, errorFunc, @
    cam.PopModelMatrix!

    -- Restore HDR
    render.SetToneMappingScaleLinear old

ENT.GetCursorPos = () =>
    ply = LocalPlayer()
    screen = @

    -- Get monitor screen pos & size
    Pos = screen\LocalToWorld screen.Origin
    Normal = -screen.Transform\GetUp!\GetNormalized!

    Start = ply\EyePos!
    Dir = if Moonpanel\IsFocused ply
        x, y = input.GetCursorPos!
        gui.ScreenToVector x, y
    else
        ply\GetAimVector!

    A = Normal\Dot Dir

    -- If ray is parallel or behind the screen
    if A == 0 or A > 0
        return nil

    B = Normal\Dot(Pos-Start) / A
    if (B >= 0)
        w = Moonpanel.Canvas.Resolution
        HitPos = screen.Transform\GetInverseTR! * (Start + Dir * B)
        x = HitPos.x / screen.Scale^2
        y = HitPos.y / screen.Scale^2
        if x < 0 or x > w or y < 0 or y > Moonpanel.Canvas.Resolution
            return nil
        return x, y

    return nil

ENT.GetScreenTransform = =>
    return @Transform if @Transform
    return unless @ScreenMatrix

    bone = @GetBoneMatrix 0
    return unless bone

    bone * @ScreenMatrix

ENT.TransformInputDeltas = (dX = 0, dY = 0) =>
	transform = @GetScreenTransform!
	return dX, dY unless transform

    resolution = Moonpanel.Canvas.Resolution
    sample = 64
    localScale = (@Scale or 1)^2

	canvas = @GetCanvas!
	head = canvas and canvas\GetTraceCursor!
	cx = head and head.x or resolution * 0.5
	cy = head and head.y or resolution * 0.5

    center = (transform * Vector cx * localScale, cy * localScale, 0)\ToScreen!
    right = (transform * Vector (cx + sample) * localScale, cy * localScale, 0)\ToScreen!
    down = (transform * Vector cx * localScale, (cy + sample) * localScale, 0)\ToScreen!

	xAxisX, xAxisY = right.x - center.x, right.y - center.y
	yAxisX, yAxisY = down.x - center.x, down.y - center.y

    det = xAxisX * yAxisY - yAxisX * xAxisY
    return dX, dY if math.abs(det) <= 0.0001

	-- Invert the projected panel basis at the trace head. This keeps input
	-- relative, preserves oblique-panel direction, and has no screen bounds.
	panelDX = (dX * yAxisY - dY * yAxisX) / det * sample
	panelDY = (-dX * xAxisY + dY * xAxisX) / det * sample

	-- Source look deltas are relative motion, not desktop-pixel distances.
	-- The inverse basis determines direction on oblique panels; preserve the
	-- original input magnitude so perspective cannot amplify trace speed.
	inputMagnitude = math.sqrt dX * dX + dY * dY
	panelMagnitude = math.sqrt panelDX * panelDX + panelDY * panelDY
	if inputMagnitude > 0.0001 and panelMagnitude > 0.0001
		magnitudeScale = inputMagnitude / panelMagnitude
		panelDX *= magnitudeScale
		panelDY *= magnitudeScale

	panelDX, panelDY

ENT.GetResolution = () =>
    Moonpanel.Canvas.Resolution / @Aspect, Moonpanel.Canvas.Resolution

ENT.IsSynchronized = => @__canvas\GetData! ~= nil
