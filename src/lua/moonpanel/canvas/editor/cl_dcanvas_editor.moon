vgui.Register "DMoonCanvasEditor", {
	Init: =>
		@.BaseClass.Init @
		@__selectedSocketIndex = nil
		@__lastDragSocketIndex = nil
		@__dragSocketGroup = nil
		@__editMouseWasDown = false

		defaultThink = @__slave.Think
		defaultTestHover = @__slave.TestHover
		defaultClick = @__slave.DoClick

		with @__slave
			.DoClick = ->
				defaultClick! if @__playMode and defaultClick

			.updateHoveredEntity = ->
				x, y = @LocalCursorPos!
				x = Moonpanel.Canvas.Resolution * (x / math.max @GetWide!, 1)
				y = Moonpanel.Canvas.Resolution * (y / math.max @GetTall!, 1)
				@__hoveredEntity = @__canvas\GetEntityAtScreen x, y

			.getSocketGroup = (_, socket) ->
				return unless socket
				socketType = socket\GetSocketType!
				if socketType == Moonpanel.Canvas.SocketType.Cell
					"cell"
				elseif socketType == Moonpanel.Canvas.SocketType.Path or
						socketType == Moonpanel.Canvas.SocketType.Intersection
					"topology"

			.OnDepressed = ->
				return if @__playMode or @__editMouseWasDown or
					not input.IsMouseDown MOUSE_LEFT
				@__slave\updateHoveredEntity!
				@__editMouseWasDown = true
				@__lastDragSocketIndex = nil
				@__dragSocketGroup = @__slave\getSocketGroup @__hoveredEntity
				if @__hoveredEntity and @DoEditorPress
					@DoEditorPress @__hoveredEntity
					@__lastDragSocketIndex = @__hoveredEntity\GetDataIndex!

			.OnCursorMoved = ->
				return if @__playMode or not @__editMouseWasDown
				@__slave\updateHoveredEntity!
				return unless @__hoveredEntity and @DoEditorDrag
				return unless @__slave\getSocketGroup(@__hoveredEntity) == @__dragSocketGroup
				index = @__hoveredEntity\GetDataIndex!
				if index and index ~= @__lastDragSocketIndex
					@DoEditorDrag @__hoveredEntity
					@__lastDragSocketIndex = index

			.OnReleased = ->
				return if @__playMode or not @__editMouseWasDown
				if input.IsMouseDown MOUSE_LEFT
					@__slave\MouseCapture true
					return
				@DoEditorRelease! if @DoEditorRelease
				@__lastDragSocketIndex = nil
				@__dragSocketGroup = nil
				@__editMouseWasDown = false

			.DoRightClick = ->
				if not @__playMode and not @__editMouseWasDown and
						@__hoveredEntity and @DoRightClick
					@DoRightClick @__hoveredEntity

			.Think = ->
				if @__playMode
					defaultThink! if defaultThink
				else
					@__slave\updateHoveredEntity!
					@__canvas\Think!

			.TestHover = ->
				return defaultTestHover! if @__playMode and defaultTestHover
				x, y = @LocalCursorPos!
				x = Moonpanel.Canvas.Resolution * (x / math.max @GetWide!, 1)
				y = Moonpanel.Canvas.Resolution * (y / math.max @GetTall!, 1)
				@__hoveredEntity = @__canvas\GetEntityAtScreen x, y
				return true if @__hoveredEntity
				false

		@SetPlayMode false

	PaintOver: (w, h) =>
		return if @__playMode
		if @__canvas\IsContinuous!
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

	SetPlayMode: (playMode) =>
		playMode = playMode == true
		if @__slave and @__editMouseWasDown
			@__slave\MouseCapture false
			@__editMouseWasDown = false
			@__lastDragSocketIndex = nil
			@__dragSocketGroup = nil
		if @__slave and @__playMode ~= playMode
			@__slave\MouseCapture false
			@__slave.Depressed = nil
			@__mouseCap = false
		@__playMode = playMode
		@__canvas\SetEditorGeometryVisible not @__playMode
		@__canvas\SetFocusHintOverride @__playMode
		@__hoveredEntity = nil if @__playMode

	SetSelectedSocketIndex: (index) =>
		@__selectedSocketIndex = index and math.floor tonumber(index)

}, "DMoonCanvas"
