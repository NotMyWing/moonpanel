return unless CLIENT

Moonpanel.Editor or= {}
Editor = Moonpanel.Editor

Editor.SavePath = "moonpanel/autosave.txt"
Editor.RecoveryMetaPath = "moonpanel/autosave.meta.txt"
Editor.StoredDataLoaded = false

writePanel = (path, data) ->
	file.CreateDir "moonpanel"
	serialized = Moonpanel.Canvas.SerializeData data
	return false, "Panel serialization failed" unless serialized
	file.Write path, serialized
	true

readRecoveryMetadata = ->
	return {} unless file.Exists Editor.RecoveryMetaPath, "DATA"
	contents = file.Read Editor.RecoveryMetaPath, "DATA"
	return {} unless contents
	util.JSONToTable(contents) or {}

Editor.EnsureDocument = =>
	return @Document if @Document

	@Document = Moonpanel.EditorDocument.New nil, {
		historyLimit: 128
		activeTool: @ActiveTool or "place"
		sanitize: (data) ->
			data = Moonpanel.Canvas.SanitizeData data
			if data and data.Meta and data.Meta.Continuous
				data = Moonpanel.Canvas.CanonicalizeContinuousData data
			data
		writeFile: (path, data) -> writePanel path, data
		writeRecovery: (data, metadata) ->
			ok, reason = writePanel Editor.SavePath, data
			return false, reason unless ok
			meta = {
				path: metadata.path
				dirty: metadata.dirty == true
				timestamp: os.time!
			}
			file.Write Editor.RecoveryMetaPath, util.TableToJSON(meta)
			true, meta.timestamp
		load: ->
			data = nil
			hadRecovery = file.Exists Editor.SavePath, "DATA"
			if hadRecovery
				contents = file.Read Editor.SavePath, "DATA"
				data = Moonpanel.Canvas.DeserializeData contents if contents

			metadata = readRecoveryMetadata!
			metadata.saved = true if not hadRecovery or metadata.dirty == false
			data or Editor.CurrentData or Moonpanel.Canvas.SampleData, metadata
	}
	@Document

Editor.LoadStoredData = (force = false) =>
	document = @EnsureDocument!
	if force
		document.loaded = false
		document.history = {}
		document.historyCursor = 0

	data, loadedFromDisk, metadata = document\LoadOnDemand!
	@CurrentData = data
	@OpenedFile = document.currentPath
	@StoredDataLoaded = true
	data, loadedFromDisk, metadata

Editor.EnsureStoredDataLoaded = =>
	@LoadStoredData false
	@CurrentData

Editor.GetCurrentData = =>
	document = @EnsureDocument!
	document\LoadOnDemand!
	@StoredDataLoaded = true
	@CurrentData = document\GetData!
	return @CurrentData

Editor.WriteRecovery = =>
	document = @EnsureDocument!
	document\WriteRecovery!

Editor.SaveDocument = (path) =>
	document = @EnsureDocument!
	ok, reason = document\Save path
	if ok
		@CurrentData = document\GetData!
		@OpenedFile = document.currentPath
	ok, reason
