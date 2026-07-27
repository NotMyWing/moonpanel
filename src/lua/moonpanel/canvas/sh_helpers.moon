-- Shared, side-effect-free helpers used by canvas modules.

Moonpanel.Helpers or= {}
Helpers = Moonpanel.Helpers

Helpers.tableOrEmpty = (value) ->
	type(value) == "table" and value or {}

Helpers.deepCopy = (value, seen = {}) ->
	return value unless type(value) == "table"
	return seen[value] if seen[value]
	output = {}
	seen[value] = output
	output[Helpers.deepCopy(key, seen)] = Helpers.deepCopy(child, seen) for key, child in pairs value
	output

Helpers.num = (value, default) ->
	value = tonumber value
	value == nil and default or value

Helpers.bool = (value) -> value == true

Helpers.round = (value) ->
	value >= 0 and math.floor(value + 0.5) or math.ceil(value - 0.5)

Helpers.clamp = (value, minimum, maximum) ->
	math.max minimum, math.min maximum, value

Helpers.flatIndex = (width, gridX, gridY) ->
	1 + (gridX - 1) + (gridY - 1) * (width * 2 + 1)

Helpers.copyArray = (values = {}) ->
	[value for value in *values]

Helpers.copyColor = (input, fallback) ->
	input = Helpers.tableOrEmpty input
	fallback = fallback or {}
	{
		r: math.Clamp math.floor(Helpers.num input.r, fallback.r or 255), 0, 255
		g: math.Clamp math.floor(Helpers.num input.g, fallback.g or 255), 0, 255
		b: math.Clamp math.floor(Helpers.num input.b, fallback.b or 255), 0, 255
		a: math.Clamp math.floor(Helpers.num input.a, fallback.a or 255), 0, 255
	}
