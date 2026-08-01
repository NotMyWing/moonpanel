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
