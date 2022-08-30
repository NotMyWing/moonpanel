AddCSLuaFile!

MAT_COLOR = Material "moonpanel/common/color.png"
MAT_SUN = Material "moonpanel/common/sun.png"
MAT_ERASER = Material "moonpanel/common/eraser.png"
MAT_TRIANGLE = Material "moonpanel/common/triangle.png"
MAT_POLY = Material "moonpanel/common/polyomino_cell.png"

cellBounds = (entity, scale = 1) ->
	socket = entity\GetSocket!
	ro = socket\GetRenderOrigin!
	canvas = socket\GetCanvas!
	size = math.max(1, math.min(canvas\GetBarLength!,
		canvas\GetVerticalBarLength!) - canvas\GetBarWidth!) * scale

	ro.x - size / 2, ro.y - size / 2, size, size

drawSymbol = (entity, material, scale = 0.82) ->
	return unless CLIENT

	x, y, w, h = cellBounds entity, scale
	data = entity\GetData!
	colorId = Moonpanel.Canvas.GetClueTintColor data, Moonpanel.Color.White
	color = Moonpanel.Canvas.ColorValues[colorId] or
		Moonpanel.Canvas.ColorValues[Moonpanel.Color.White]

	r, g, b, a = entity\GetCanvas!\ApplyEntityVisualColor color, entity\GetSocket!
	surface.SetDrawColor r, g, b, a
	surface.SetMaterial material
	surface.DrawTexturedRect x, y, w, h

class Moonpanel.Canvas.Entities.Color extends Moonpanel.Canvas.Entities.BaseCell
	Render: =>
		drawSymbol @, MAT_COLOR

class Moonpanel.Canvas.Entities.Sun extends Moonpanel.Canvas.Entities.BaseCell
	Render: =>
		drawSymbol @, MAT_SUN

class Moonpanel.Canvas.Entities.Eraser extends Moonpanel.Canvas.Entities.BaseCell
	Render: =>
		drawSymbol @, MAT_ERASER

class Moonpanel.Canvas.Entities.Triangle extends Moonpanel.Canvas.Entities.BaseCell
	Render: =>
		return unless CLIENT

		data = @GetData!
		count = math.Clamp data.Count or 1, 1, 4
		x, y, w, h = cellBounds @, 0.82
		size = w * 0.24
		spacing = w * 0.08
		totalWidth = count * size + (count - 1) * spacing
		startX = x + w / 2 - totalWidth / 2
		startY = y + h / 2 - size / 2

		colorId = Moonpanel.Canvas.GetClueTintColor data, Moonpanel.Color.Orange
		color = Moonpanel.Canvas.ColorValues[colorId] or
			Moonpanel.Canvas.ColorValues[Moonpanel.Color.Orange]

		r, g, b, a = @GetCanvas!\ApplyEntityVisualColor color, @GetSocket!
		surface.SetDrawColor r, g, b, a
		surface.SetMaterial MAT_TRIANGLE
		for i = 1, count
			surface.DrawTexturedRect startX + (i - 1) * (size + spacing), startY, size, size

class Moonpanel.Canvas.Entities.Polyomino extends Moonpanel.Canvas.Entities.BaseCell
	Render: =>
		return unless CLIENT

		data = @GetData!
		shape = data.Shape or { { 1 } }
		rows = #shape
		cols = #(shape[1] or {})
		return if rows == 0 or cols == 0

		x, y, w, h = cellBounds @, data.Rotational and 0.62 or 0.74
		maxDim = math.max rows, cols
		spacing = w * 0.035
		cellSize = math.min (w - spacing * (maxDim - 1)) / maxDim,
			w * 0.22

		totalW = cols * cellSize + (cols - 1) * spacing
		totalH = rows * cellSize + (rows - 1) * spacing
		offsetX = x + w / 2 - totalW / 2
		offsetY = y + h / 2 - totalH / 2

		colorId = Moonpanel.Canvas.GetClueTintColor data, Moonpanel.Color.Yellow
		color = Moonpanel.Canvas.ColorValues[colorId] or
			Moonpanel.Canvas.ColorValues[Moonpanel.Color.Yellow]

		r, g, b, a = @GetCanvas!\ApplyEntityVisualColor color, @GetSocket!
		surface.SetDrawColor r, g, b, a
		surface.SetMaterial MAT_POLY unless data.Negative

		rotational = data.Rotational == true
		renderScale = rotational and 4 or 1
		center = Vector x + w / 2, y + h / 2, 0
		if rotational
			render.PushFilterMag TEXFILTER.ANISOTROPIC
			render.PushFilterMin TEXFILTER.ANISOTROPIC
			matrix = Matrix!
			matrix\Translate center
			matrix\Rotate Angle 0, -15, 0
			matrix\Scale Vector 1 / renderScale, 1 / renderScale, 1
			matrix\Translate -center
			cam.PushModelMatrix matrix

		for row = 1, rows
			for col = 1, cols
				if shape[row][col] == 1
					drawX = offsetX + (col - 1) * (cellSize + spacing)
					drawY = offsetY + (row - 1) * (cellSize + spacing)
					renderX = rotational and center.x + (drawX - center.x) * renderScale or drawX
					renderY = rotational and center.y + (drawY - center.y) * renderScale or drawY
					renderSize = cellSize * renderScale
					if data.Negative
						thickness = math.max 1, math.floor(cellSize * 0.16 * renderScale)
						surface.DrawOutlinedRect renderX, renderY, renderSize, renderSize, thickness
					elseif rotational
						surface.DrawTexturedRect renderX, renderY, renderSize, renderSize
					else
						surface.DrawTexturedRect drawX, drawY, cellSize, cellSize

		cam.PopModelMatrix! if rotational
		if rotational
			render.PopFilterMag!
			render.PopFilterMin!

class Moonpanel.Canvas.Entities.CellInvisible extends Moonpanel.Canvas.Entities.BaseCell
	@CanonicalType = "Invisible"

	Render: =>
		return unless CLIENT
		return unless @GetCanvas!\GetEditorGeometryVisible!

		x, y, w, h = cellBounds @, 0.9
		surface.SetDrawColor 0, 0, 0, 80
		surface.DrawRect x, y, w, h
