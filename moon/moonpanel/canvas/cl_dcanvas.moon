vgui.Register "DMoonCanvas", {
	Init: =>
		@__canvas = Moonpanel.Canvas.Canvas nil, true
		@__canvas\RebuildNodes!
		@__canvas\InitPathFinder!

		@__canvas.OnStart = ->
			surface.PlaySound "moonpanel/panel_start_tracing.ogg"

		@__canvas.OnEnd = =>
			surface.PlaySound "moonpanel/panel_abort_tracing.ogg"

		@SetText ""

		@SetMouseInputEnabled true

		AccessorFunc @, "__playMode", "PlayMode"
		@SetPlayMode true

		rendering = false
		id = tostring @
		hook.Add "Think", id, ->
			if not IsValid @
				hook.Remove "Think", id
				return

			if not rendering and @IsVisible!
				rendering = true
				@__canvas\AllocateRT!

			elseif rendering and not @IsVisible!
				rendering = false
				@__canvas\DeallocateRT!

	Paint: (w, h) =>
		@__canvas\RenderRT!
		@__canvas\Paint w, h

	TestHover: =>
		if @__playMode
			pathfinder = @__canvas\GetPathFinder!
			return if not pathfinder

			if not @__mouseCap
				x, y = @LocalCursorPos!
				x = Moonpanel.Canvas.Resolution * (x / @GetWide!)
				y = Moonpanel.Canvas.Resolution * (y / @GetTall!)

				not not pathfinder\getClosestNode x, y, 32

	DoClick: =>
		if @__playMode
			pathfinder = @__canvas\GetPathFinder!
			return if not pathfinder

			if @__mouseCap
				@__mouseCap = false
				@__canvas\End!
				return

			x, y = @LocalCursorPos!
			x = Moonpanel.Canvas.Resolution * (x / @GetWide!)
			y = Moonpanel.Canvas.Resolution * (y / @GetTall!)

			node = pathfinder\getClosestNode x, y, 32
			if node and @__canvas\Start node.id, LocalPlayer!
				@__mouseCap = true
				@__mouseCapX = node.screenX / Moonpanel.Canvas.Resolution * @GetWide!
				@__mouseCapY = node.screenY / Moonpanel.Canvas.Resolution * @GetTall!

	Think: =>
		if @__playMode
			pathfinder = @__canvas\GetPathFinder!
			return if not pathfinder

			if @__mouseCap
				x, y = @LocalCursorPos!
				cursor = (pathfinder.cursors or {})[1]
				if cursor
					cX = cursor.x / Moonpanel.Canvas.Resolution * @GetWide!
					cY = cursor.y / Moonpanel.Canvas.Resolution * @GetTall!

					dX = x - cX + 0.25
					dY = y - cY + 0.25

					@__canvas\ApplyDeltas dX, dY

			@__canvas\Think!

	GetElementAt: =>
		return if not @__clientData

	OnRemove: =>
		@__canvas\DeallocateRT!

	SetData: (data) =>
		@__canvas\SetData data
		@__canvas\RebuildNodes!
		@__canvas\InitPathFinder!

}, "DButton"

concommand.Add "themp_test_vgui", ->
	with vgui.Create "DFrame"
		\SetSize Moonpanel.Canvas.Resolution,
			Moonpanel.Canvas.Resolution

		\Center!
		\MakePopup!

		with \Add "DMoonCanvas"
			\Dock FILL
			\SetData Moonpanel.Canvas.SampleData
