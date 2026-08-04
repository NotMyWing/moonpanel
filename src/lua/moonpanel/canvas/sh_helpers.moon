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

UINT32 = 4294967296
CRC_MASK = 4294967295
CRC_POLYNOMIAL = 3988292384
crcXor = (left, right) -> bit.bxor(left, right) % UINT32
crcTable = {}
for byte = 0, 255
	value = byte
	for _ = 1, 8
		value = if value % 2 == 1
			crcXor math.floor(value / 2), CRC_POLYNOMIAL
		else
			math.floor value / 2
	crcTable[byte] = value

Helpers.CRC32Begin = CRC_MASK
Helpers.CRC32AppendByte = (crc, byte) ->
	crcXor math.floor(crc / 256), crcTable[crcXor(crc % 256, byte % 256)]

Helpers.CRC32AppendNumber = (crc, value) ->
	value = math.floor(tonumber(value) or 0) % UINT32
	for _ = 1, 4
		crc = Helpers.CRC32AppendByte crc, value % 256
		value = math.floor value / 256
	crc

Helpers.CRC32Finish = (crc) -> crcXor crc, CRC_MASK

Helpers.copyColor = (input, fallback) ->
	input = Helpers.tableOrEmpty input
	fallback = fallback or {}
	{
		r: math.Clamp math.floor(Helpers.num input.r, fallback.r or 255), 0, 255
		g: math.Clamp math.floor(Helpers.num input.g, fallback.g or 255), 0, 255
		b: math.Clamp math.floor(Helpers.num input.b, fallback.b or 255), 0, 255
		a: math.Clamp math.floor(Helpers.num input.a, fallback.a or 255), 0, 255
	}

Helpers.terminalColor = (input) ->
	color = Helpers.copyColor input
	if ColorToHSV and HSVToColor and Color
		hue, saturation, value = ColorToHSV Color color.r, color.g, color.b
		if value > 0.92 and saturation < 0.25
			return { r: 255, g: 255, b: 255, a: color.a }
		saturation = math.max saturation, 0.85
		value *= 0.97
		converted = HSVToColor hue, saturation, value
		return { r: converted.r, g: converted.g, b: converted.b, a: color.a }
	r, g, b = color.r / 255, color.g / 255, color.b / 255
	maximum, minimum = math.max(r, g, b), math.min(r, g, b)
	delta = maximum - minimum
	if maximum > 0 and delta / maximum < 0.25 and maximum > 0.92
		return { r: 255, g: 255, b: 255, a: color.a }
	hue = 0
	if delta > 0
		if maximum == r
			hue = ((g - b) / delta) % 6
		elseif maximum == g
			hue = (b - r) / delta + 2
		else
			hue = (r - g) / delta + 4
		hue *= 60
		hue += 360 if hue < 0
	saturation = math.max(delta / maximum, 0.85)
	value = maximum * 0.97
	chroma = value * saturation
	sector = hue / 60
	secondary = chroma * (1 - math.abs(sector % 2 - 1))
	red, green, blue = 0, 0, 0
	if sector < 1
		red, green = chroma, secondary
	elseif sector < 2
		red, green = secondary, chroma
	elseif sector < 3
		green, blue = chroma, secondary
	elseif sector < 4
		green, blue = secondary, chroma
	elseif sector < 5
		red, blue = secondary, chroma
	else
		red, blue = chroma, secondary
	minimum = value - chroma
	result = {
		r: Helpers.round((red + minimum) * 255)
		g: Helpers.round((green + minimum) * 255)
		b: Helpers.round((blue + minimum) * 255)
		a: color.a
	}
	result
