isVisibleOnScreen = (panel) ->
	while IsValid panel
		return false unless panel\IsVisible!
		panel = panel\GetParent!
	true

vgui.Register "DMoonCanvas", {
	Init: =>
		@__canvas = Moonpanel.Canvas.Canvas!
		@__canvas\SetSoundSuppressed "PresenceLoop", true
		@__canvas\SetSoundSuppressed "SolvingLoop", true
		@__canvas\SetSoundEnabled true

		@SetText ""

		@SetMouseInputEnabled true

		rendering = false

		hook.Add "Think", @, ->
			if isVisibleOnScreen @
				unless rendering and @__canvas\CanRender!
					@__canvas\AllocateRT @GetForceRTEviction!
					rendering = @__canvas\CanRender!

			elseif rendering
				rendering = false
				@__canvas\DeallocateRT!
				@__canvas\StopSounds!

		with @__slave = @Add "DButton"
			\Dock FILL
			\SetMouseInputEnabled true
			\SetDoubleClickingEnabled false
			\SetText ""

			.DoClick = ->
				if @__mouseCap
					@__mouseCap = false
					@__canvas\End!
					return

				x, y = @LocalCursorPos!
				x = Moonpanel.Canvas.Resolution * (x / @GetWide!)
				y = Moonpanel.Canvas.Resolution * (y / @GetTall!)

				node = @__canvas\FindStartNode x, y, 32
				if node and @__canvas\Start LocalPlayer!, node.id
					@__mouseCap = true
					@__mouseCapX = node.screenX / Moonpanel.Canvas.Resolution * @GetWide!
					@__mouseCapY = node.screenY / Moonpanel.Canvas.Resolution * @GetTall!

			.Think = ->
				if @__mouseCap
					x, y = @LocalCursorPos!
					cursor = @__canvas\GetTraceCursor!
					if cursor
						cX = cursor.x / Moonpanel.Canvas.Resolution * @GetWide!
						cY = cursor.y / Moonpanel.Canvas.Resolution * @GetTall!
						if @__canvas\IsContinuous!
							panelWidth = @__canvas\GetDimensions!
							period = @__canvas\GetBarLength! *
								panelWidth /
								Moonpanel.Canvas.Resolution * @GetWide!
							cX = Moonpanel.Canvas.NearestPeriodicCoordinate cX, x, period

						dX = x - cX + 0.25
						dY = y - cY + 0.25

						@__canvas\ApplyDeltas dX, dY

				@__canvas\Think!

			.Paint = ->

			.TestHover = ->
				return true if @__mouseCap
				x, y = @LocalCursorPos!
				x = Moonpanel.Canvas.Resolution * (x / @GetWide!)
				y = Moonpanel.Canvas.Resolution * (y / @GetTall!)
				node = @__canvas\FindStartNode x, y, 32
				not not node

	Paint: (w, h) =>
		@__canvas\RenderRT!
		@__canvas\Paint w, h

	OnRemove: =>
		@__canvas\StopSounds!
		@__canvas\DeallocateRT!

	ImportData: (data) =>
		@__canvas\ImportData data

	ExportData: => @__canvas\ExportData!

	GetCanvas: => @__canvas

	SetForceRTEviction: (enabled) =>
		@__forceRTEviction = enabled == true

	GetForceRTEviction: => @__forceRTEviction == true

}, "Panel"
