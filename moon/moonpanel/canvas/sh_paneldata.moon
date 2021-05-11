AddCSLuaFile!

Moonpanel.Canvas.SanitizeData = (data) ->
	input = istable(data) and data or {}
	output = {}

	--
	-- META
	--
	meta = istable(data.Meta) and data.Meta or {}

	output.Meta = {}
	output.Meta.Width = math.Clamp (tonumber(meta.Width)  or 3),
		1, 10

	output.Meta.Height = math.Clamp (tonumber(meta.Height) or 3),
		1, 10

	output.Meta.Symmetry = math.floor math.Clamp (tonumber(meta.Symmetry) or 0),
		0, Moonpanel.Canvas.Symmetry.Horizontal

	--
	-- DIM
	--
	dim = istable(data.Dim) and data.Dim or {}

	output.Dim = {}
	output.Dim.BarLength = math.Clamp (tonumber(dim.BarLength) or 25),
		1, 100

	output.Dim.BarWidth = math.Clamp (tonumber(dim.BarWidth) or 3),
		1, 100

	--
	-- ENTITIES
	--
	entities = istable(data.Entities) and data.Entities or {}

	output.Entities = {}
	for i = 1, (output.Meta.Width * 2 - 1) * (output.Meta.Height * 2 - 1)
		entity = {}

		if reference = entities[i]
			entity.Type = isnumber(reference.Type) and reference.Type

		table.insert output.Entities, entity

	output

Moonpanel.Canvas.DeserializeData = (data) ->
	Moonpanel.Canvas.SanitizeData util.JSONToTable data

Moonpanel.Canvas.SerializeData = (table) ->
	util.TableToJSON Moonpanel.Canvas.SanitizeData table
