-- Pure editor document state. It deliberately has no Derma, realm, timing,
-- or file-system dependencies; adapters provide those operations.

Document = {}
Document.__index = Document

deepCopy = (value, seen = {}) ->
	return value unless type(value) == "table"
	return seen[value] if seen[value]
	output = {}
	seen[value] = output
	output[deepCopy(key, seen)] = deepCopy(child, seen) for key, child in pairs value
	output

stableEncode = (value, output = {}) ->
	valueType = type value
	switch valueType
		when "nil"
			table.insert output, "n;"
		when "boolean"
			table.insert output, value and "b1;" or "b0;"
		when "number"
			table.insert output, "d#{string.format "%.17g", value};"
		when "string"
			table.insert output, "s#{#value}:#{value}"
		when "table"
			keys = [key for key in pairs value]
			table.sort keys, (a, b) ->
				ta, tb = type(a), type(b)
				return ta < tb if ta ~= tb
				return a < b if ta == "number" or ta == "string"
				tostring(a) < tostring(b)
			table.insert output, "t#{#keys}{"
			for key in *keys
				stableEncode key, output
				stableEncode value[key], output
			table.insert output, "}"
		else
			error "unsupported editor document value: #{valueType}"
	table.concat output

Document.New = (data, options = {}) ->
	self = setmetatable {}, Document
	self.options = options
	self.historyLimit = math.max 1, math.floor(options.historyLimit or 128)
	self.history = {}
	self.historyCursor = 0
	self.selection = nil
	self.activeTool = options.activeTool or "place"
	self.placementPreset = deepCopy options.placementPreset or {}
	self.currentPath = options.currentPath
	self.loaded = data ~= nil
	self.lastError = nil
	self.recoveryTimestamp = nil
	self.data = self\_sanitize data or {}
	self.savedBaseline = self\_signature self.data
	self.dirty = false
	self

Document._sanitize = (data) =>
	sanitize = @options.sanitize or (value) -> deepCopy value or {}
	deepCopy sanitize deepCopy data

Document._signature = (data) =>
	return @options.signature(data) if @options.signature
	stableEncode data

Document._refreshDirty = =>
	@dirty = @_signature(@data) ~= @savedBaseline
	@dirty

Document.GetData = => deepCopy @data
Document.GetMutableData = => @data
Document.IsDirty = => @dirty
Document.CanUndo = => @historyCursor > 0
Document.CanRedo = => @historyCursor < #@history

Document.BeginEdit = (label = "Edit panel", mergeKey) =>
	return false, "edit already in progress" if @transaction
	@transaction = {
		:label
		:mergeKey
		before: @GetData!
	}
	true

Document.CancelEdit = =>
	return false unless @transaction
	@data = @transaction.before
	@transaction = nil
	@_refreshDirty!
	true

Document.CommitEdit = (data) =>
	@BeginEdit! unless @transaction
	transaction = @transaction
	after = @_sanitize data or @data
	@transaction = nil
	if @_signature(transaction.before) == @_signature(after)
		@data = after
		@_refreshDirty!
		return false

	while #@history > @historyCursor
		table.remove @history
	previous = @history[@historyCursor]
	if transaction.mergeKey and previous and previous.mergeKey == transaction.mergeKey
		previous.after = deepCopy after
		previous.label = transaction.label
	else
		table.insert @history, {
			label: transaction.label
			mergeKey: transaction.mergeKey
			before: transaction.before
			after: deepCopy after
		}
		@historyCursor = #@history
		if #@history > @historyLimit
			table.remove @history, 1
			@historyCursor = #@history
	@data = after
	@_refreshDirty!
	true

Document.BreakMerge = =>
	previous = @history[@historyCursor]
	previous.mergeKey = nil if previous

Document.Undo = =>
	@CancelEdit! if @transaction
	return false unless @CanUndo!
	entry = @history[@historyCursor]
	@data = deepCopy entry.before
	@historyCursor -= 1
	@_refreshDirty!
	true, entry.label

Document.Redo = =>
	@CancelEdit! if @transaction
	return false unless @CanRedo!
	@historyCursor += 1
	entry = @history[@historyCursor]
	@data = deepCopy entry.after
	@_refreshDirty!
	true, entry.label

Document.Replace = (data, options = {}) =>
	@transaction = nil
	@data = @_sanitize data
	@selection = nil
	if options.resetHistory ~= false
		@history = {}
		@historyCursor = 0
	if options.clearPath then @currentPath = nil
	elseif options.path ~= nil then @currentPath = options.path
	@savedBaseline = @_signature(@data) if options.markSaved
	@_refreshDirty!
	@GetData!

Document.MarkSaved = (path) =>
	@currentPath = path if path ~= nil
	@BreakMerge!
	@savedBaseline = @_signature @data
	@_refreshDirty!

Document.Save = (path = @currentPath) =>
	return false, "path required" unless path
	return false, "no save adapter" unless @options.writeFile
	ok, reason = @options.writeFile path, @GetData!
	if ok == false
		@lastError = reason or "save failed"
		return false, @lastError
	@lastError = nil
	@MarkSaved path
	true

Document.WriteRecovery = =>
	return false, "no recovery adapter" unless @options.writeRecovery
	ok, timestamp = @options.writeRecovery @GetData!, {
		path: @currentPath
		dirty: @dirty
	}
	if ok == false
		@lastError = timestamp or "recovery failed"
		return false, @lastError
	@recoveryTimestamp = timestamp or (@options.now and @options.now! or 0)
	@lastError = nil
	true

Document.LoadOnDemand = =>
	return @GetData!, false if @loaded
	@loaded = true
	return @GetData!, false unless @options.load
	data, metadata = @options.load!
	if data
		@data = @_sanitize data
		@currentPath = metadata.path if metadata and metadata.path
		@savedBaseline = @_signature(@data) if metadata and metadata.saved
		@_refreshDirty!
		return @GetData!, true, metadata
	@GetData!, false, metadata

Document.SetSelection = (index) =>
	index = tonumber index
	@selection = index and math.floor(index) or nil
	@selection

Document.SetPlacementPreset = (preset) => @placementPreset = deepCopy preset or {}
Document.GetPlacementPreset = => deepCopy @placementPreset

Document.CalculateDockLayout = (width, options = {}) ->
	width = math.max 1, math.floor(width or 1)
	handle = options.handleWidth or 5
	minimumCanvas = options.minimumCanvas or 480
	drawerWidth = options.drawerVisible and (options.drawerWidth or 260) or 0
	available = math.max 1, width - drawerWidth
	libraryWidth = math.max 0, options.libraryWidth or 220
	inspectorWidth = math.max 0, options.inspectorWidth or 300
	inspectorMinimum = options.inspectorMinimum or 260
	inspectorVisible = options.inspectorVisible ~= false
	inspectorVisible = false if inspectorVisible and available < minimumCanvas + inspectorMinimum + handle
	if inspectorVisible
		inspectorWidth = math.min inspectorWidth, available - minimumCanvas - handle
	else inspectorWidth = 0
	libraryVisible = options.libraryVisible ~= false and
		available >= minimumCanvas + libraryWidth + handle +
			(inspectorVisible and inspectorWidth + handle or 0)
	libraryWidth = 0 unless libraryVisible
	canvasWidth = available - libraryWidth - inspectorWidth -
		(libraryVisible and handle or 0) - (inspectorVisible and handle or 0)
	{
		:drawerWidth
		:libraryVisible
		:libraryWidth
		:inspectorVisible
		:inspectorWidth
		canvasWidth: math.max 1, canvasWidth
		handleWidth: handle
	}

-- Normalize clue data for semantic comparison. Unknown fields are retained so
-- right-click sampling and exact-match removal remain faithful as the clue
-- format grows. Only representation details and omitted defaults are folded.
tableOrEmpty = (value) ->
	if type(value) == "table" then value else {}

trimPolyominoShape = (shape) ->
	shape = tableOrEmpty shape
	local minX, minY, maxX, maxY
	for y, row in pairs shape
		if type(y) == "number" and type(row) == "table"
			for x, cell in pairs row
				if type(x) == "number" and cell == 1
					minX = minX and math.min(minX, x) or x
					maxX = maxX and math.max(maxX, x) or x
					minY = minY and math.min(minY, y) or y
					maxY = maxY and math.max(maxY, y) or y
	return { { 0 } } unless minX
	trimmed = {}
	for y = minY, maxY
		row = {}
		for x = minX, maxX
			row[#row + 1] = shape[y] and shape[y][x] == 1 and 1 or 0
		trimmed[#trimmed + 1] = row
	trimmed

normalizeForEquality = (typeName, value) ->
	data = deepCopy(tableOrEmpty(value))

	-- Legacy render tint field.
	if data.Color ~= nil and data.TintColor == nil
		data.TintColor = data.Color
	data.Color = nil

	switch typeName
		when "Color", "Sun", "Eraser", "Start", "End", "Disjoint"
			data.RuleColor or= Moonpanel.Color.Black
		when "Triangle"
			data.RuleColor or= Moonpanel.Color.Orange
			data.Count = math.floor math.Clamp(tonumber(data.Count) or 1, 1, 3)
		when "Polyomino"
			data.RuleColor or= Moonpanel.Color.Yellow
			data.Shape = trimPolyominoShape(data.Shape or { { 1 } })
			data.Rotational = data.Rotational == true
			data.Negative = data.Negative == true
		when "Hexagon"
			data.RuleColor or= Moonpanel.Color.Black
			data.TraceRole = math.floor math.Clamp(tonumber(data.TraceRole) or 0, 0, 2)
			data.Negative = data.Negative == true
			data.Invisible = data.Invisible == true

	data

Document.SemanticEqual = (a, b) ->
	return false unless a and b and a.Type == b.Type
	left = stableEncode(normalizeForEquality(a.Type, a.Data))
	right = stableEncode(normalizeForEquality(b.Type, b.Data))
	left == right

Document.DeepCopy = deepCopy
Document.StableEncode = stableEncode
Document.NormalizeForEquality = normalizeForEquality

Moonpanel or= {}
Moonpanel.EditorDocument = Document
return Document
