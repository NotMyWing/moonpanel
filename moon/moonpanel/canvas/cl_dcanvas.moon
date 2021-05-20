vgui.Register "DMoonCanvas", {
	Init: =>
		@__canvas = Moonpanel.Canvas.Canvas!
		@__canvas\SetupSounds!

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
				@__canvas\StopSounds!

		with @__slave = @Add "DButton"
			\Dock FILL
			\SetMouseInputEnabled true
			\SetText ""

			.DoClick = ->
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
					if node and @__canvas\Start LocalPlayer!, node.id
						@__mouseCap = true
						@__mouseCapX = node.screenX / Moonpanel.Canvas.Resolution * @GetWide!
						@__mouseCapY = node.screenY / Moonpanel.Canvas.Resolution * @GetTall!

				elseif @__hoveredEntity and @DoClick
					@DoClick @__hoveredEntity

			.Think = ->
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

			.OnRemove = ->
				@__canvas\StopSounds!
				@__canvas\DeallocateRT!

			.Paint = ->

			.TestHover = ->
				x, y = @LocalCursorPos!
				if @__playMode
					pathfinder = @__canvas\GetPathFinder!
					return if not pathfinder

					if not @__mouseCap
						x = Moonpanel.Canvas.Resolution * (x / @GetWide!)
						y = Moonpanel.Canvas.Resolution * (y / @GetTall!)

						not not pathfinder\getClosestNode x, y, 32
				else
					x = Moonpanel.Canvas.Resolution * (x / @GetWide!)
					y = Moonpanel.Canvas.Resolution * (y / @GetTall!)

					@__hoveredEntity = @__canvas\GetEntityAtScreen x, y
					return true if @__hoveredEntity

					false

	GetHoveredEntity: =>
		@__hoveredEntity

	Paint: (w, h) =>
		@__canvas\RenderRT!
		@__canvas\Paint w, h

	ImportData: (data) =>
		@__canvas\ImportData data

	ExportData: => @__canvas\ExportData!

	GetCanvas: => @__canvas

}, "Panel"

concommand.Add "themp_test_vgui", ->
	with vgui.Create "DFrame"
		\SetSize Moonpanel.Canvas.Resolution,
			Moonpanel.Canvas.Resolution + 64

		\Center!
		\MakePopup!

		local panel
		panel = with \Add "DMoonCanvas"
			\Dock FILL
			\ImportData Moonpanel.Canvas.SanitizeData Moonpanel.Canvas.SampleData
			.PaintOver = (_, w, h) ->
				return if panel\GetPlayMode!

				margin = 0.015 * math.min w, h

				if hovered = panel\GetHoveredEntity!
					draw.SimpleText hovered.__class.__name, "DermaLarge",
						w - margin, margin, Color(255, 255, 255), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP

			.DoClick = (entity) =>
				if entity\GetHandlerType! == Moonpanel.Canvas.HandlerType.Intersection
					canvas = panel\GetCanvas!

					x, y = entity\GetX!, entity\GetY!

					canvas\SetIntersectionAt x, y, Moonpanel.Canvas.Entities.Start canvas

		with \Add "DButton"
			\Dock BOTTOM

			\SetText "Switch to Edit Mode"
			.DoClick = ->
				nextPlayMode = not panel\GetPlayMode!
				\SetText if nextPlayMode
					"Switch to Edit Mode"
				else
					"Switch to Play Mode"

				panel\SetPlayMode nextPlayMode