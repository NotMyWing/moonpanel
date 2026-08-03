return unless CLIENT

Moonpanel.Editor or= {}
Editor = Moonpanel.Editor

BUILTIN_ROOT = "data_static/moonpanel/presets/thewitness"
BUILTIN_CATEGORIES = {
	{ id: "colors", title: "Colors" }
	{ id: "suns", title: "Suns" }
	{ id: "suns2", title: "Suns 2" }
	{ id: "suns3", title: "Suns 3" }
	{ id: "suns4", title: "Suns 4" }
}

numericFileSort = (left, right) ->
	leftNumber = tonumber string.match left, "^(%d+)%.txt$"
	rightNumber = tonumber string.match right, "^(%d+)%.txt$"
	return left < right unless leftNumber and rightNumber
	leftNumber == rightNumber and left < right or leftNumber < rightNumber

readBuiltin = (entry) ->
	return entry.data if entry.data
	contents = file.Read entry.path, "GAME"
	return nil unless contents
	entry.data = Moonpanel.Canvas.DeserializeData contents
	entry.data

Editor.GetBuiltInPanels = =>
	return @BuiltInPanels if @BuiltInPanels
	entries = {}
	for category in *BUILTIN_CATEGORIES
		files = file.Find "#{BUILTIN_ROOT}/#{category.id}/*.txt", "GAME"
		table.sort files or {}, numericFileSort
		for fileName in *(files or {})
			stem = string.StripExtension fileName
			table.insert entries, {
				id: "#{category.id}/#{stem}"
				category: category.id
				categoryTitle: category.title
				title: "#{category.title} #{stem}"
				path: "#{BUILTIN_ROOT}/#{category.id}/#{fileName}"
			}
	@BuiltInPanels = entries
	entries

Editor.RefreshBuiltInPanels = =>
	@BuiltInPanels = nil
	@GetBuiltInPanels!

Editor.LoadBuiltInPanel = (id) =>
	for entry in *@GetBuiltInPanels!
		if entry.id == id
			data = readBuiltin entry
			return data, entry if data
	nil, "Built-in panel is missing or invalid."

Editor.IsBuiltInAvailable = (id) ->
	data = Editor\LoadBuiltInPanel id
	data ~= nil

Editor.BuiltInRoot = BUILTIN_ROOT
