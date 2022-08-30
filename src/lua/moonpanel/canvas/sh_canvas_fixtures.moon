AddCSLuaFile!

return unless SERVER

flatIndex = (width, gridX, gridY) ->
	1 + (gridX - 1) + (gridY - 1) * (width * 2 + 1)

intersectionIndex = (width, x, y) ->
	flatIndex width, (x - 1) * 2 + 1, (y - 1) * 2 + 1

hpathIndex = (width, x, y) ->
	flatIndex width, x * 2, (y - 1) * 2 + 1

cellIndex = (width, x, y) ->
	flatIndex width, x * 2, y * 2

baseData = (width, height) ->
	count = (width * 2 + 1) * (height * 2 + 1)
	entities = {}
	for i = 1, count
		entities[i] = {}

	{
		SchemaVersion: Moonpanel.Canvas.SchemaVersion
		Meta: {
			Width: width
			Height: height
			Symmetry: Moonpanel.Canvas.Symmetry.None
		}
		Dim: {
			BarLength: 25
			BarWidth: 4
			DisjointLength: Moonpanel.Canvas.DefaultDisjointLength
		}
		Entities: entities
	}

nodeAt = (canvas, x, y) ->
	canvas\GetIntersectionSocketAt(x, y)\GetPathNode!

runFixture = (fixture) ->
	canvas = Moonpanel.Canvas.Canvas Moonpanel.Canvas.SanitizeData fixture.data
	canvas.__pathFinder.stacks = {
		[(nodeAt canvas, xy[1], xy[2]).id for xy in *fixture.trace]
	}
	canvas.__pathFinder\syncCompatibility!

	ctx = canvas\BuildSolutionContext!
	result = canvas\ValidateSolution ctx
	ok = result.success == fixture.success

	print "[moonpanel fixture] #{fixture.name}: #{ok and "PASS" or "FAIL"}"
	unless ok
		PrintTable result

	ok

Moonpanel.Canvas.BuildFixtures = ->
	fixtures = {}

	do
		data = baseData 1, 1
		data.Entities[cellIndex 1, 1, 1] = {
			Type: "Triangle"
			Data: { Count: 1, RuleColor: Moonpanel.Color.Orange }
		}
		table.insert fixtures, {
			name: "triangle pass"
			:data
			trace: { { 1, 1 }, { 2, 1 } }
			success: true
		}

	do
		data = baseData 1, 1
		data.Entities[cellIndex 1, 1, 1] = {
			Type: "Triangle"
			Data: { Count: 2, RuleColor: Moonpanel.Color.Orange }
		}
		table.insert fixtures, {
			name: "triangle fail"
			:data
			trace: { { 1, 1 }, { 2, 1 } }
			success: false
		}

	do
		data = baseData 1, 1
		data.Entities[hpathIndex 1, 1, 1] = {
			Type: "Hexagon"
			Data: { RuleColor: Moonpanel.Color.Black }
		}
		table.insert fixtures, {
			name: "hexagon path pass"
			:data
			trace: { { 1, 1 }, { 2, 1 } }
			success: true
		}

	do
		data = baseData 2, 1
		data.Entities[cellIndex 2, 1, 1] = {
			Type: "Sun"
			Data: { RuleColor: Moonpanel.Color.White }
		}
		data.Entities[cellIndex 2, 2, 1] = {
			Type: "Sun"
			Data: { RuleColor: Moonpanel.Color.White }
		}
		table.insert fixtures, {
			name: "sun pair pass"
			:data
			trace: { { 1, 1 }, { 2, 1 } }
			success: true
		}

	do
		data = baseData 1, 1
		data.Entities[cellIndex 1, 1, 1] = {
			Type: "Sun"
			Data: { RuleColor: Moonpanel.Color.White }
		}
		table.insert fixtures, {
			name: "sun pair fail"
			:data
			trace: { { 1, 1 }, { 2, 1 } }
			success: false
		}

	do
		data = baseData 2, 1
		data.Entities[cellIndex 2, 1, 1] = {
			Type: "Color"
			Data: { RuleColor: Moonpanel.Color.Black }
		}
		data.Entities[cellIndex 2, 2, 1] = {
			Type: "Color"
			Data: { RuleColor: Moonpanel.Color.White }
		}
		table.insert fixtures, {
			name: "color group fail"
			:data
			trace: { { 1, 1 }, { 2, 1 } }
			success: false
		}

	do
		data = baseData 2, 1
		data.Entities[cellIndex 2, 1, 1] = {
			Type: "Color"
			Data: { RuleColor: Moonpanel.Color.Black }
		}
		data.Entities[cellIndex 2, 2, 1] = {
			Type: "Color"
			Data: { RuleColor: Moonpanel.Color.White }
		}
		table.insert fixtures, {
			name: "color split pass"
			:data
			trace: { { 2, 1 }, { 2, 2 } }
			success: true
		}

	do
		data = baseData 1, 1
		data.Entities[cellIndex 1, 1, 1] = {
			Type: "Polyomino"
			Data: {
				RuleColor: Moonpanel.Color.Yellow
				Shape: { { 1 } }
			}
		}
		table.insert fixtures, {
			name: "polyomino single pass"
			:data
			trace: { { 1, 1 }, { 2, 1 } }
			success: true
		}

	do
		data = baseData 2, 1
		data.Entities[cellIndex 2, 1, 1] = {
			Type: "Polyomino"
			Data: {
				RuleColor: Moonpanel.Color.Yellow
				Shape: { { 1 } }
			}
		}
		table.insert fixtures, {
			name: "polyomino size fail"
			:data
			trace: { { 1, 1 }, { 2, 1 } }
			success: false
		}

	do
		data = baseData 2, 1
		data.Entities[cellIndex 2, 1, 1] = {
			Type: "Triangle"
			Data: { Count: 2, RuleColor: Moonpanel.Color.Orange }
		}
		data.Entities[cellIndex 2, 2, 1] = {
			Type: "Eraser"
			Data: { RuleColor: Moonpanel.Color.White }
		}
		table.insert fixtures, {
			name: "eraser suppression pass"
			:data
			trace: { { 1, 1 }, { 2, 1 } }
			success: true
		}

	fixtures

concommand.Add "moonpanel_run_fixtures", ->
	pass = 0
	fail = 0
	for fixture in *Moonpanel.Canvas.BuildFixtures!
		if runFixture fixture
			pass += 1
		else
			fail += 1

	print "[moonpanel fixture] #{pass} passed, #{fail} failed"
