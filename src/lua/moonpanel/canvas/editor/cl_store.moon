return unless CLIENT

Moonpanel.Editor or= {}
Editor = Moonpanel.Editor

savePath = "moonpanel/autosave.txt"
recoveryMetaPath = "moonpanel/autosave.meta.txt"
writePanel = (path, data) ->
	file.CreateDir "moonpanel"
	serialized = Moonpanel.Canvas.SerializeData data
	return false, "Panel serialization failed" unless serialized
	file.Write path, serialized
	true

readRecoveryMetadata = ->
	return {} unless file.Exists recoveryMetaPath, "DATA"
	contents = file.Read recoveryMetaPath, "DATA"
	return {} unless contents
	util.JSONToTable(contents) or {}

writeRecoveryMetadata = (path, dirty, source) ->
	meta = { :path, dirty: dirty == true, timestamp: os.time! }
	meta.source = source if source and source.kind
	file.Write recoveryMetaPath, util.TableToJSON(meta)
	meta.timestamp

Editor.EnsureDocument = =>
	return @Document if @Document

	fallbackData, @CurrentData = @CurrentData, nil
	@Document = Moonpanel.EditorDocument.New nil, {
		historyLimit: 128
		activeTool: @ActiveTool or "place"
		sanitize: (data) ->
			data = Moonpanel.Canvas.SanitizeData data
			if data and data.Meta and data.Meta.Continuous
				data = Moonpanel.Canvas.CanonicalizeContinuousData data
			data
		writeFile: (path, data) -> writePanel path, data
		writeSession: (path, source) ->
			writeRecoveryMetadata path, false, source
			true
		writeRecovery: (data, metadata) ->
			ok, reason = writePanel savePath, data
			return false, reason unless ok
			true, writeRecoveryMetadata metadata.path, metadata.dirty, metadata.source
		load: ->
			data = nil
			metadata = readRecoveryMetadata!
			hadRecovery = file.Exists savePath, "DATA"
			useRecovery = hadRecovery and metadata.dirty ~= false
			if useRecovery
				contents = file.Read savePath, "DATA"
				data = Moonpanel.Canvas.DeserializeData contents if contents
			elseif metadata.path and file.Exists metadata.path, "DATA"
				contents = file.Read metadata.path, "DATA"
				data = Moonpanel.Canvas.DeserializeData contents if contents
			elseif metadata.source and metadata.source.kind == "builtin"
				data = Moonpanel.Editor\LoadBuiltInPanel metadata.source.id

			metadata.saved = not useRecovery
			data or fallbackData or Moonpanel.EditorDocument.FreshPanel!, metadata
	}
	@Document

Editor.GetCurrentData = =>
	document = @EnsureDocument!
	document\LoadOnDemand!
	document\GetData!
