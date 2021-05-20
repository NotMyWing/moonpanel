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

			.DoRightClick = ->
				if not @__playMode and @__hoveredEntity and @DoRightClick
					@DoRightClick @__hoveredEntity

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

						node = pathfinder\getClosestNode x, y, 32
						not not node
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

surface.CreateFont "Roboto1",
	font: "Roboto"
	size: 32

surface.CreateFont "Roboto2",
	font: "Roboto"
	size: 24

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
				margin = 0.015 * math.min w, h

				text = panel\GetPlayMode! and "Play Mode" or "Edit Mode"

				draw.SimpleText text, "Roboto1",
					margin, margin, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP

				text = switch panel\GetCanvas!\GetSymmetryType!
					when 0
						"No Symmetry"
					when 1
						"Vertical Symmetry"
					when 2
						"Horizontal Symmetry"
					when 3
						"Rotational Symmetry"

				draw.SimpleText text, "Roboto2",
					margin, margin + 36, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP

				if hovered = panel\GetHoveredEntity!
					draw.SimpleText hovered.__class.__name, "Roboto1",
						w - margin, margin, Color(255, 255, 255), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP

					if entity = hovered\GetEntity!
						draw.SimpleText entity.__class.__name, "Roboto2",
							w - margin, margin + 36, Color(255, 255, 255), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP

			.DoClick = (socket) =>
				if socket\GetSocketType! == Moonpanel.Canvas.SocketType.Intersection
					if entity = socket\GetEntity!
						if entity.__class == Moonpanel.Canvas.Entities.Start
							socket\SetEntity!
							return

					socket\SetEntity Moonpanel.Canvas.Entities.Start!
					socket\GetCanvas!\RecalculateClient!

			.DoRightClick = (socket) =>
				if socket\GetSocketType! == Moonpanel.Canvas.SocketType.Intersection
					if entity = socket\GetEntity!
						if entity.__class == Moonpanel.Canvas.Entities.End
							socket\SetEntity!
							return

					socket\SetEntity Moonpanel.Canvas.Entities.End!
					socket\GetCanvas!\RecalculateClient!

		with \Add "Panel"
			\Dock BOTTOM
			\InvalidateParent true

			width = \GetWide!

			with \Add "DButton"
				\Dock LEFT
				\SetWide width / 2

				\SetText "Switch to Edit Mode"
				.DoClick = ->
					nextPlayMode = not panel\GetPlayMode!
					\SetText if nextPlayMode
						"Switch to Edit Mode"
					else
						"Switch to Play Mode"

					panel\SetPlayMode nextPlayMode

			with \Add "DButton"
				\Dock LEFT
				\SetWide width / 2

				\SetText "Switch to Vertical Symmetry"

				symmetries = { 0, 1, 2, 3 }
				currentSymmetry = 1
				.DoClick = ->
					canvas = panel\GetCanvas!
					currentSymmetry = next symmetries, currentSymmetry
					if not currentSymmetry
						currentSymmetry = 1

					print symmetries[currentSymmetry]
					canvas\SetSymmetryType symmetries[currentSymmetry]

					nextSymmetry = next symmetries, currentSymmetry
					if not nextSymmetry
						nextSymmetry = 1

					\SetText switch symmetries[nextSymmetry]
						when 0
							"Switch to No Symmetry"
						when 1
							"Switch to Vertical Symmetry"
						when 2
							"Switch to Horizontal Symmetry"
						when 3
							"Switch to Rotational Symmetry"
