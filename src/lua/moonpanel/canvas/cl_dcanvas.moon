vgui.Register "DMoonCanvas", {
	Init: =>
		@__canvas = Moonpanel.Canvas.Canvas!
		@__canvas\SetSoundSuppressed "PresenceLoop", true
		@__canvas\SetSoundSuppressed "SolvingLoop", true
		@__canvas\SetSoundEnabled true

		@SetText ""

		@SetMouseInputEnabled true

		@SetPlayMode true
		@__selectedSocketIndex = nil
		@__lastDragSocketIndex = nil
		@__editMouseWasDown = false

		rendering = false

		hook.Add "Think", @, ->
			if not rendering and @IsVisible!
				rendering = true
				@__canvas\AllocateRT!

			elseif rendering and not @IsVisible!
				rendering = false
				@__canvas\DeallocateRT!
				@__canvas\StopSounds!

		with @__slave = @Add "DButton"
			\Dock FILL
			\SetMouseInputEnabled true
			\SetText ""

			.DoClick = ->
				if @__playMode
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

				-- Edit-mode presses are handled in Think so shift-drag painting
				-- produces one continuous gesture instead of release clicks.

			.DoRightClick = ->
				if not @__playMode and @__hoveredEntity and @DoRightClick
					@DoRightClick @__hoveredEntity

			.Think = ->
				if @__playMode
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
				else
					x, y = @LocalCursorPos!
					x = Moonpanel.Canvas.Resolution * (x / math.max @GetWide!, 1)
					y = Moonpanel.Canvas.Resolution * (y / math.max @GetTall!, 1)
					@__hoveredEntity = @__canvas\GetEntityAtScreen x, y

					mouseDown = input.IsMouseDown MOUSE_LEFT
					shiftDown = input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT)
					if mouseDown and not @__editMouseWasDown
						@__lastDragSocketIndex = nil
						if @__hoveredEntity and @DoEditorPress
							@DoEditorPress @__hoveredEntity, shiftDown
							@__lastDragSocketIndex = @__hoveredEntity\GetDataIndex!
					elseif mouseDown and shiftDown and @__hoveredEntity and @DoEditorDrag
						index = @__hoveredEntity\GetDataIndex!
						if index and index ~= @__lastDragSocketIndex
							@DoEditorDrag @__hoveredEntity
							@__lastDragSocketIndex = index
					elseif not mouseDown and @__editMouseWasDown
						@DoEditorRelease! if @DoEditorRelease
						@__lastDragSocketIndex = nil

					@__editMouseWasDown = mouseDown

			.OnRemove = ->
				@__canvas\StopSounds!
				@__canvas\DeallocateRT!

			.Paint = ->

			.TestHover = ->
				x, y = @LocalCursorPos!
				if @__playMode
					if not @__mouseCap
						x = Moonpanel.Canvas.Resolution * (x / @GetWide!)
						y = Moonpanel.Canvas.Resolution * (y / @GetTall!)

						node = @__canvas\FindStartNode x, y, 32
						not not node
				else
					x = Moonpanel.Canvas.Resolution * (x / @GetWide!)
					y = Moonpanel.Canvas.Resolution * (y / @GetTall!)

					@__hoveredEntity = @__canvas\GetEntityAtScreen x, y
					return true if @__hoveredEntity

					false

	Paint: (w, h) =>
		@__canvas\RenderRT!
		@__canvas\Paint w, h

	PaintOver: (w, h) =>
		return if @__playMode
		if @__canvas\IsContinuous!
			-- Paired edge chevrons mark the wrap without redrawing the hidden
			-- duplicate seam column or obstructing its horizontal path sockets.
			surface.SetDrawColor 93, 207, 255, 150
			mid = h * 0.5
			draw.NoTexture!
			surface.DrawPoly {
				{ x: 3, y: mid }, { x: 11, y: mid - 6 }, { x: 11, y: mid + 6 }
			}
			surface.DrawPoly {
				{ x: w - 3, y: mid }, { x: w - 11, y: mid - 6 },
				{ x: w - 11, y: mid + 6 }
			}

		drawSocket = (socket, color, radius, width = 2) ->
			return unless socket and socket.GetRenderOrigin
			origin = socket\GetRenderOrigin!
			x = origin.x / Moonpanel.Canvas.Resolution * w
			y = origin.y / Moonpanel.Canvas.Resolution * h
			for offset = 0, width - 1
				surface.DrawCircle x, y, radius + offset, color.r, color.g, color.b, color.a

		if @__selectedSocketIndex
			drawSocket @__canvas\GetSocketAtDataIndex(@__selectedSocketIndex),
				Color(93, 207, 255, 245), 11, 2

		if @__hoveredEntity
			compatible = not @CanTargetSocket or @CanTargetSocket @__hoveredEntity
			color = compatible and Color(230, 246, 255, 220) or Color(245, 100, 104, 220)
			drawSocket @__hoveredEntity, color, 8, 1

	ImportData: (data) =>
		@__canvas\ImportData data

	ExportData: => @__canvas\ExportData!

	GetCanvas: => @__canvas

	SetPlayMode: (playMode) =>
		@__playMode = playMode == true
		@__canvas\SetEditorGeometryVisible not @__playMode
		@__canvas\SetFocusHintOverride @__playMode
		@__hoveredEntity = nil if @__playMode

	SetSelectedSocketIndex: (index) =>
		@__selectedSocketIndex = index and math.floor tonumber(index)

}, "Panel"
