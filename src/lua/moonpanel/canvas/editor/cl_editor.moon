return unless CLIENT

Moonpanel.Editor or= {}
Editor = Moonpanel.Editor

C = {
	window: Color 20, 23, 29
	panel: Color 28, 32, 40
	raised: Color 36, 41, 51
	inset: Color 22, 26, 33
	border: Color 56, 64, 78
	text: Color 232, 238, 244
	muted: Color 145, 156, 170
	accent: Color 71, 192, 235
	accentDim: Color 40, 107, 132
	hover: Color 48, 56, 68
	danger: Color 229, 85, 91
	warning: Color 242, 181, 70
	success: Color 91, 209, 142
}

-- Share C with other editor modules
Editor.C = C

surface.CreateFont "MoonpanelEditorTitle", font: "Roboto", size: 20, weight: 700, extended: true
surface.CreateFont "MoonpanelEditorHeading", font: "Roboto", size: 16, weight: 700, extended: true
surface.CreateFont "MoonpanelEditorBody", font: "Roboto", size: 14, weight: 500, extended: true
surface.CreateFont "MoonpanelEditorSmall", font: "Roboto", size: 12, weight: 500, extended: true

MATERIALS = {
	Color: Material "moonpanel/common/color.png", "noclamp smooth"
	Sun: Material "moonpanel/common/sun.png", "noclamp smooth"
	Eraser: Material "moonpanel/common/eraser.png", "noclamp smooth"
	Triangle: Material "moonpanel/common/triangle.png", "noclamp smooth"
	Polyomino: Material "moonpanel/editor/polyo.png", "noclamp smooth"
	Start: Material "moonpanel/editor/start.png", "noclamp smooth"
	End: Material "moonpanel/editor/end.png", "noclamp smooth"
	Disjoint: Material "moonpanel/editor/disjoint.png", "noclamp smooth"
	Hexagon: Material "moonpanel/common/hexagon.png", "noclamp smooth"
	HexagonNegative: Material "moonpanel/common/hexagon_hollow.png", "noclamp smooth"
	Invisible: Material "moonpanel/editor/invisible_layer2.png", "noclamp smooth"
}
Editor.MATERIALS = MATERIALS

-- Adapted from WireMod's Expression 2 "in editor" animation by the WireMod
-- contributors (Apache-2.0). Moonpanel substitutes randomized clue particles.
activeEditors = {}
clueMaterials = {
	MATERIALS.Color, MATERIALS.Sun, MATERIALS.Eraser,
	MATERIALS.Triangle, MATERIALS.Polyomino, MATERIALS.Hexagon
}
clueSprites = {}

Editor.SetPresence = (_, ply, open) ->
	return unless IsValid ply
	activeEditors[ply] = open == true or nil

hook.Add "EntityRemoved", "Moonpanel Editor Presence", (entity) ->
	activeEditors[entity] = nil

timer.Create "Moonpanel Editor Presence", 0.65, 0, ->
	for ply in pairs activeEditors
		continue unless IsValid ply
		bone = ply\LookupBone("ValveBiped.Bip01_Head1") or
			ply\LookupBone("ValveBiped.HC_Head_Bone") or 0
		position = ply\GetBonePosition bone
		continue unless position
		table.insert clueSprites, {
			material: clueMaterials[math.random #clueMaterials]
			position: position + Vector(math.random(-7, 7), math.random(-7, 7), 15)
			color: Moonpanel.Canvas.ColorValues[math.random 2, 9]
			born: CurTime!
			rotation: math.random 0, 359
			spin: math.random(-90, 90)
		}

hook.Add "PostDrawTranslucentRenderables", "Moonpanel Editor Presence",
	(_, skybox) ->
		return if skybox
		now = CurTime!
		for index = #clueSprites, 1, -1
			sprite = clueSprites[index]
			life = (now - sprite.born) / 2.2
			if life >= 1
				table.remove clueSprites, index
				continue
			color = sprite.color
			render.SetMaterial sprite.material
			position = sprite.position + Vector(0, 0, life * 40)
			size = Lerp life, 9, 13
			render.DrawQuadEasy position, (EyePos! - position)\GetNormalized!,
				size, size, Color(color.r, color.g, color.b, (1 - life) * 230),
				sprite.rotation + (now - sprite.born) * sprite.spin

Helpers = Moonpanel.Helpers
deepCopy = Helpers.deepCopy
clearChildren = Helpers.clearChildren
colorValue = Helpers.colorValue

-- Load submodules
include "cl_brushes.lua"
include "cl_tooltip.lua"
include "cl_sidebar.lua"
include "cl_windmill.lua"

isEmpty = (entry) -> not entry or not entry.Type

styledButton = (parent, text, callback, width) ->
	button = with parent\Add "DButton"
		.Label = text
		\SetText ""
		\SetTall 30
		\SetWide width if width
		.DoClick = callback
		.Paint = (_, w, h) ->
			background = if _.Depressed then C.accentDim elseif _.Hovered then C.hover else C.raised
			draw.RoundedBox 4, 0, 0, w, h, background
			draw.SimpleText _.Label or text, "MoonpanelEditorBody", w / 2, h / 2, C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
	button

addLabel = (parent, text, font = "MoonpanelEditorBody", color = C.text, tall = 20) ->
	with parent\Add "DLabel"
		\Dock TOP
		\DockMargin 10, 4, 10, 2
		\SetTall tall
		\SetFont font
		\SetTextColor color
		\SetText text

----
-- Status, title, recovery
----

Editor.SetStatus = (text, tone = C.muted) =>
	@StatusText = text or "Ready"
	if IsValid @StatusLabel
		@StatusLabel\SetText @StatusText
		@StatusLabel\SetTextColor tone

Editor.UpdateTitle = =>
	return unless IsValid @Frame
	path = @Document\GetPath!
	source = @Document\GetSource!
	name = path and string.StripExtension(string.GetFileFromFilename(path)) or "Untitled"
	if source.kind == "builtin"
		name = source.title or source.id or "Built-in panel"
	windowTitle = "Moonpanel Editor - #{name}#{@Document\IsDirty! and " *" or ""}"
	@Frame\SetTitle windowTitle
	if IsValid @FileStateLabel
		state = if source.kind == "builtin"
			if @Document\IsDirty! then "Built-in panel • Unsaved changes" else "Built-in panel • Read-only"
		elseif @Document\IsDirty! then "Unsaved changes" elseif path then "Saved" else "Untitled panel"
		location = if source.kind == "builtin" then source.id elseif path then path
		@FileStateLabel\SetText (location and "#{state}  •  #{location}" or state)
		@FileStateLabel\SetTextColor @Document\IsDirty! and C.warning or C.success
	if IsValid @SaveButton
		@SaveButton.Label = source.kind == "builtin" and "Save As" or "Save"
	@UndoButton\SetEnabled @Document\CanUndo! if IsValid @UndoButton
	@RedoButton\SetEnabled @Document\CanRedo! if IsValid @RedoButton

Editor.ScheduleRecovery = =>
	return unless @Document and @Document\IsDirty!
	timer.Create "Moonpanel Editor Recovery", 1, 1, ->
		return unless Editor.Document and Editor.Document\IsDirty!
		ok, reason = Editor.Document\WriteRecovery!
		Editor\SetStatus reason, C.danger unless ok

----
-- Document / canvas sync
----

Editor.GetEffectiveSurfaceSpec = (data) =>
	data or= @Document and @Document\GetData! or Moonpanel.EditorDocument.FreshPanel!
	kind = @SurfaceSpec and @SurfaceSpec.kind or Moonpanel.Canvas.SurfaceKind.Flat
	continuous = data and data.Meta and data.Meta.Continuous == true
	Moonpanel.Canvas.MakeSurfaceSpec kind, continuous

Editor.SyncCanvas = (rebuild = true) =>
	data = @Document\GetData!
	@OpenedFile = @Document\GetPath!
	@RefreshBrushValidity! if @RefreshBrushValidity
	if IsValid @FrameCanvas
		@FrameCanvas\GetCanvas!\SetSurfaceSpec @GetEffectiveSurfaceSpec(data)
		@FrameCanvas\ImportData data
		@FrameCanvas\SetSelectedSocketIndex nil
	@UpdateTitle!
	@RebuildSidebar! if rebuild

Editor.CommitData = (label, data, mergeKey, rebuild = true) =>
	@Document\BeginEdit label, mergeKey unless @Document\IsEditing!
	changed = @Document\CommitEdit data
	if changed
		@SyncCanvas rebuild
		@ScheduleRecovery!
		@SetStatus label, C.text
	else
		@UpdateTitle!
	changed

----
-- Canvas interaction
----

Editor.PaintSocket = (socket, allowToggle = false) =>
	return false unless socket
	brush = @GetBrushForSocket socket
	return false unless brush and brush.typeName

	unless Moonpanel.Canvas.GetEntityClass brush.typeName, socket\GetSocketType!
		@SetStatus "#{brush.typeName} cannot be placed on this socket.", C.danger
		return false
	unless brush.valid
		@SetStatus brush.warning or "Invalid clue configuration.", C.danger
		return false

	entity = socket\GetEntity!
	occupied = entity and not entity\IsBase!
	matching = occupied and @BrushMatchesEntity brush, socket
	return false if matching and not allowToggle

	label = if matching then "Remove clue" elseif occupied then "Replace clue" else "Place clue"
	@BeginGesture label
	if matching
		socket\SetEntity!
		@_gestureCanvasExport = true
		return true

	if Moonpanel.Canvas.SetSocketEntityData socket, brush.typeName, deepCopy(brush.data or {})
		@_gestureCanvasExport = true
		return true
	false

Editor.CanvasPress = (socket) =>
	return if @TestMode or not socket
	@PendingSocket = nil
	@GestureDragged = false

	switch @activeMode
		when "erase"
			@EraseSocket socket
		when "recolor"
			@RecolorSocket socket
		else
			-- Defer a normal placement until release so an exact-match removal
			-- only happens on a deliberate click, never at the start of a drag.
			@PendingSocket = socket

Editor.CanvasDrag = (socket) =>
	return if @TestMode or not socket
	switch @activeMode
		when "erase"
			@EraseSocket socket
		when "recolor"
			@RecolorSocket socket
		else
			unless @GestureDragged
				@GestureDragged = true
				@PaintSocket @PendingSocket, false if @PendingSocket
			@PaintSocket socket, false

Editor.CanvasRelease = =>
	if not @TestMode and @activeMode == "place" and @PendingSocket and not @GestureDragged
		@PaintSocket @PendingSocket, true

	@PendingSocket = nil
	@GestureDragged = false
	return unless @GestureActive

	if @_gestureCanvasExport and @Document\CommitEdit @FrameCanvas\ExportData!
		@SyncCanvas (@sidebarTab == "panel")
		@ScheduleRecovery!
	elseif not @_gestureCanvasExport
		@Document\CancelEdit!
	@GestureActive = false
	@_gestureCanvasExport = false
	@UpdateTitle!

Editor.CanvasRightClick = (socket) =>
	return if @TestMode or not socket
	@PickupClue socket

Editor.CanTargetSocket = (socket) =>
	return false unless socket and not @TestMode
	true

----
-- Erase and Recolor utilities
----

Editor.EraseSocket = (socket) =>
	entity = socket and socket\GetEntity!
	return false unless entity and not entity\IsBase!
	@BeginGesture "Erase clue"
	socket\SetEntity!
	@_gestureCanvasExport = true
	true

Editor.RecolorSocket = (socket) =>
	entity = socket and socket\GetEntity!
	return false unless entity and not entity\IsBase!
	exported = entity\ExportData!
	return false unless exported and exported.Data
	unless Editor.ClueSupportsRuleColor exported.Type, exported.Data
		@SetStatus "This clue has no rule color to change.", C.danger
		return false

	brush = @GetFocusedBrush!
	unless brush and brush.data and brush.data.RuleColor ~= nil
		@SetStatus "Select a clue with a rule color first.", C.danger
		return false
	newColor = brush.data.RuleColor
	oldColor = exported.Data.RuleColor
	oldTint = exported.Data.TintColor or exported.Data.Color
	return false if oldColor == newColor and oldTint == nil

	exported.Data.RuleColor = newColor
	exported.Data.TintColor = nil
	exported.Data.Color = nil
	@BeginGesture "Recolor clue"
	if Moonpanel.Canvas.SetSocketEntityData socket, exported.Type, deepCopy(exported.Data)
		@_gestureCanvasExport = true
		return true
	false

----
-- Undo / Redo
----

Editor.Undo = =>
	@ExitTestMode! if @TestMode
	ok, label = @Document\Undo!
	if ok
		@SyncCanvas false
		@RefreshAppearanceControls! if @RefreshAppearanceControls
		@ScheduleRecovery!
		@SetStatus "Undo: #{label}", C.text

Editor.Redo = =>
	@ExitTestMode! if @TestMode
	ok, label = @Document\Redo!
	if ok
		@SyncCanvas false
		@RefreshAppearanceControls! if @RefreshAppearanceControls
		@ScheduleRecovery!
		@SetStatus "Redo: #{label}", C.text

----
-- File operations
----

Editor.Save = (path, callback) =>
	return @ShowSaveAs callback if @Document\IsReadOnly!
	path or= @Document\GetPath!
	return @ShowSaveAs callback unless path
	ok, reason = @Document\Save path
	if ok
		@OpenedFile = path
		@Document\WriteRecovery true
		@AddRecent path
		@UpdateTitle!
		@SetStatus "Saved #{path}", C.success
	else @SetStatus reason, C.danger
	callback ok if callback
	ok

Editor.SaveAs = (path, callback) =>
	ok, reason = @Document\SaveAs path
	if ok
		@OpenedFile = path
		@Document\WriteRecovery true
		@AddRecent path
		@UpdateTitle!
		@SetStatus "Saved #{path}", C.success
	else @SetStatus reason, C.danger
	callback ok if callback
	ok

Editor.ShowSaveAs = (callback) =>
	accept = (name) ->
		unless name and name ~= ""
			callback false if callback
			return
		name = string.StripExtension name
		name = string.gsub name, "[^%w_%-]", "_"
		Editor\SaveAs "moonpanel/#{name}.txt", callback
	cancel = -> callback false if callback
	Derma_StringRequest "Save Moonpanel", "Save relative to data/moonpanel:", "untitled",
		accept, cancel, "Save", "Cancel"

Editor.WithDirtyGuard = (action) =>
	unless @Document\IsDirty!
		action!
		return
	Derma_Query "Save changes before continuing?", "Unsaved Moonpanel",
		"Save", (-> Editor\Save nil, (ok) -> action! if ok),
		"Discard", action, "Cancel"

Editor.NewPanel = =>
	@ExitTestMode! if @TestMode
	@WithDirtyGuard ->
		Editor.Document\Replace Moonpanel.EditorDocument.FreshPanel!,
			resetHistory: true, markSaved: true, clearPath: true
		Editor\RefreshBrushValidity!
		Editor\SyncCanvas!
		Editor\SetStatus "New panel", C.text

Editor.OpenFile = (path) =>
	return unless path and file.Exists path, "DATA"
	@ExitTestMode! if @TestMode
	@WithDirtyGuard ->
		contents = file.Read path, "DATA"
		data = contents and Moonpanel.Canvas.DeserializeData contents
		unless data
			Editor\SetStatus "Could not read #{path}", C.danger
			return
		Editor.Document\Replace data, resetHistory: true, markSaved: true, path: path
		Editor\RefreshBrushValidity!
		Editor\AddRecent path
		Editor\SyncCanvas!
		Editor\SetStatus "Opened #{path}", C.success

Editor.OpenBuiltIn = (id) =>
	@ExitTestMode! if @TestMode
	data, entry = Editor\LoadBuiltInPanel id
	unless data
		@SetStatus entry or "Could not read built-in panel", C.danger
		return false
	@WithDirtyGuard ->
		Editor.Document\Replace data,
			resetHistory: true
			markSaved: true
			clearPath: true
			source: {
				kind: "builtin"
				id: entry.id
				title: entry.title
				category: entry.category
			}
		Editor\RefreshBrushValidity!
		Editor\SyncCanvas!
		Editor\SetStatus "Opened built-in #{entry.title}", C.success
	true

Editor.ImportJsonDialog = =>
	@ExitTestMode! if @TestMode
	Derma_StringRequest "Import Moonpanel JSON", "Paste canonical or legacy JSON:", "", (text) ->
		raw = util.JSONToTable text or ""
		unless raw
			Editor\SetStatus "Invalid JSON", C.danger
			return
		Editor\WithDirtyGuard ->
			Editor.Document\Replace raw, resetHistory: true, clearPath: true
			Editor\RefreshBrushValidity!
			Editor\SyncCanvas!
			Editor\ScheduleRecovery!
			Editor\SetStatus "Imported JSON", C.success

Editor.ClearPanel = =>
	@ExitTestMode! if @TestMode
	count, data = 0, @Document\GetData!
	for index, entry in ipairs data.Entities
		unless isEmpty entry
			count += 1
			data.Entities[index] = {}
	return if count == 0
	Derma_Query "Remove all #{count} clues? This remains undoable.", "Clear panel", "Clear", (->
		Editor\CommitData "Clear all clues", data), "Cancel"

Editor.AddRecent = (path) =>
	@RecentFiles or= {}
	for index = #@RecentFiles, 1, -1
		table.remove @RecentFiles, index if @RecentFiles[index] == path
	table.insert @RecentFiles, 1, path
	while #@RecentFiles > 6
		table.remove @RecentFiles
	cookie.Set "moonpanel_editor_recent", table.concat(@RecentFiles, "|") if cookie

Editor.LoadRecent = =>
	return if @RecentFiles
	@RecentFiles = {}
	stored = cookie and cookie.GetString("moonpanel_editor_recent", "") or ""
	for path in string.gmatch stored, "[^|]+"
		table.insert @RecentFiles, path if file.Exists path, "DATA"

Editor.UpdateDocuments = =>
	return unless IsValid @DocumentList
	@LoadRecent!
	@RefreshBuiltInPanels! if @RefreshBuiltInPanels
	@DocumentList\Clear!
	recent = @DocumentList\AddNode "Recent"
	for path in *@RecentFiles
		with recent\AddNode string.StripExtension string.GetFileFromFilename path
			.FilePath = path
			\SetIcon "icon16/page_white.png"
	with @DocumentList\AddNode "Saved panels"
		\MakeFolder "moonpanel", "DATA", true
		\SetExpanded true
	builtins = @GetBuiltInPanels!
	if #builtins > 0
		root = @DocumentList\AddNode "Built-in panels"
		root\SetExpanded true
		categoryNodes = {}
		for entry in *builtins
			categoryNodes[entry.category] or= root\AddNode entry.categoryTitle
			with categoryNodes[entry.category]\AddNode entry.title
				.BuiltInId = entry.id
				\SetIcon "icon16/page_white.png"

----
-- Test mode
----

Editor.EnterTestMode = =>
	return if @TestMode
	@CanvasRelease! if @GestureActive or @PendingSocket
	@TestMode = true
	@TestSnapshot = @Document\GetData!
	@FrameCanvas\GetCanvas!\SetSurfaceSpec @GetEffectiveSurfaceSpec(@TestSnapshot)
	@FrameCanvas\ImportData @TestSnapshot
	@FrameCanvas\SetSelectedSocketIndex nil
	@FrameCanvas\SetPlayMode true
	@Sidebar\SetEnabled false
	@Sidebar\SetAlpha 90
	@TestButton.Testing = true if IsValid @TestButton
	@SetStatus "Test mode: trace the puzzle exactly as it will play", C.accent

Editor.ExitTestMode = =>
	return unless @TestMode
	canvas = @FrameCanvas and @FrameCanvas\GetCanvas!
	canvas\End true if canvas and canvas.End
	@TestMode = false
	@TestSnapshot = nil
	if IsValid @FrameCanvas
		data = @Document\GetData!
		@FrameCanvas\SetPlayMode false
		@FrameCanvas\GetCanvas!\SetSurfaceSpec @GetEffectiveSurfaceSpec(data)
		@FrameCanvas\ImportData data
	if IsValid @Sidebar
		@Sidebar\SetEnabled true
		@Sidebar\SetAlpha 255
	@TestButton.Testing = false if IsValid @TestButton
	@SetStatus "Edit mode", C.text

Editor.ToggleTestMode = =>
	if @TestMode then @ExitTestMode! else @EnterTestMode!

----
-- Keyboard
----

Editor.IsTyping = =>
	focus = vgui.GetKeyboardFocus!
	return false unless IsValid focus
	className = focus\GetClassName!
	className == "TextEntry" or className == "DTextEntry" or className == "DNumberWang"

Editor.HandleKey = (code) =>
	return if @IsTyping!
	control = input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL)
	shift = input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT)

	if @TestMode
		if control and code == KEY_S
			if shift then @ShowSaveAs! else @Save!
		elseif code == KEY_T or code == KEY_ESCAPE
			@ExitTestMode!
		return

	if control and code == KEY_S
		if shift then @ShowSaveAs! else @Save!
		return
	if control and code == KEY_N
		@NewPanel!
		return
	if control and code == KEY_Z
		if shift then @Redo! else @Undo!
		return
	if control and code == KEY_Y
		@Redo!
		return

	switch code
		when KEY_E then @SetActiveMode "erase"
		when KEY_R then @SetActiveMode "recolor"
		when KEY_B then @SetActiveMode "place"
		when KEY_T then @EnterTestMode!

----
-- Top toolbar
----

topButton = (parent, text, callback, width) ->
	with styledButton parent, text, callback, width
		\Dock LEFT
		\DockMargin 0, 4, 6, 4

Editor.BuildTopBar = (parent) =>
	with topButton parent, "Documents", (-> Editor\ToggleDocuments!), 92
		\DockMargin 8, 4, 10, 4
	topButton parent, "New", (-> Editor\NewPanel!), 52
	@SaveButton = topButton parent, "Save", (-> Editor\Save!), 64
	@UndoButton = topButton parent, "Undo", (-> Editor\Undo!), 58
	@RedoButton = topButton parent, "Redo", (-> Editor\Redo!), 58

	-- File menu, styled like the rest of the editor controls.
	openFileMenu = ->
		menu = DermaMenu!
		menu\AddOption "Save As...", -> Editor\ShowSaveAs!
		menu\AddOption "Import JSON...", -> Editor\ImportJsonDialog!
		menu\AddOption "Import The Windmill...", -> Editor\ShowWindmillImporter!
		menu\AddOption "Export JSON", ->
			data = Editor.Document\GetData!
			SetClipboardText util.TableToJSON data
			Editor\SetStatus "Exported JSON to clipboard", C.success
		menu\AddSpacer!
		menu\AddOption "Clear Panel", -> Editor\ClearPanel!
		menu\Open!
	topButton parent, "File", openFileMenu, 52

	@TestButton = with parent\Add "DButton"
		\Dock RIGHT
		\DockMargin 6, 4, 8, 4
		\SetWide 112
		\SetText ""
		.DoClick = -> Editor\ToggleTestMode!
		.Paint = (_, w, h) ->
			draw.RoundedBox 4, 0, 0, w, h, _.Testing and C.warning or (_.Hovered and C.hover or C.accentDim)
			draw.SimpleText _.Testing and "Return to Edit" or "Test Puzzle  [T]", "MoonpanelEditorBody", w / 2, h / 2, C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER

----
-- Documents drawer
----

Editor.BuildDocuments = (parent) =>
	addLabel parent, "DOCUMENTS", "MoonpanelEditorHeading", C.text, 28
	@FileStateLabel = with addLabel parent, "", "MoonpanelEditorSmall", C.muted, 34
		\SetWrap true
	row = with parent\Add "DPanel"
		\Dock TOP
		\DockMargin 8, 4, 8, 6
		\SetTall 30
		.Paint = nil
	with styledButton row, "Import JSON", (-> Editor\ImportJsonDialog!), 104
		\Dock LEFT
	with styledButton row, "Windmill", (-> Editor\ShowWindmillImporter!), 86
		\Dock LEFT
	with styledButton row, "Refresh", (-> Editor\UpdateDocuments!), 76
		\Dock RIGHT
	@DocumentList = with parent\Add "DTree"
		\Dock FILL
		\DockMargin 6, 0, 6, 6
		.DoClick = (_, node) ->
			if node.BuiltInId
				Editor\OpenBuiltIn node.BuiltInId
			else
				path = node.FilePath or (node.GetFileName and node\GetFileName!)
				Editor\OpenFile path if path and path ~= ""

----
-- Canvas
----

Editor.BuildCanvas = (parent) =>
	parent.Paint = (_, w, h) ->
		draw.RoundedBox 0, 0, 0, w, h, C.window
		surface.SetDrawColor 31, 36, 44, 180
		surface.DrawLine x, 0, x, h for x = 0, w, 32
		surface.DrawLine 0, y, w, y for y = 0, h, 32
	@FrameCanvas = with parent\Add "DMoonCanvas"
		\GetCanvas!\SetSurfaceSpec @GetEffectiveSurfaceSpec(@Document\GetData!)
		\SetPlayMode false
		\ImportData @Document\GetData!
		.DoEditorPress = (_, socket) -> Editor\CanvasPress socket
		.DoEditorDrag = (_, socket) -> Editor\CanvasDrag socket
		.DoEditorRelease = -> Editor\CanvasRelease!
		.DoRightClick = (_, socket) -> Editor\CanvasRightClick socket
		.CanTargetSocket = (_, socket) -> Editor\CanTargetSocket socket
	parent.PerformLayout = (_, w, h) ->
		available = math.max 1, math.min(w - 32, h - 32)
		side = math.max 1, available
		Editor.FrameCanvas\SetPos math.floor((w - side) / 2), math.floor((h - side) / 2)
		Editor.FrameCanvas\SetSize side, side

----
-- Body / layout
----

Editor.ToggleDocuments = =>
	@DocumentsVisible = not @DocumentsVisible
	@UpdateDocuments! if @DocumentsVisible
	@Body\InvalidateLayout true
	@SaveLayoutCookies!

Editor.SaveLayoutCookies = =>
	return unless cookie and IsValid @Frame
	cookie.Set "moonpanel_editor_w", @Frame\GetWide!
	cookie.Set "moonpanel_editor_h", @Frame\GetTall!

Editor.BuildBody = (parent) =>
	@DocumentsVisible = false

	-- Documents drawer (left)
	@FileDrawer = with parent\Add "DPanel"
		\SetVisible false
		\SetZPos 20
		.Paint = (_, w, h) -> draw.RoundedBox 4, 0, 0, w, h, C.panel
	@BuildDocuments @FileDrawer

	-- Main sidebar (Clues / Panel / Appearance)
	@Sidebar = with parent\Add "DPanel"
		\SetZPos 20
		.Paint = (_, w, h) -> draw.RoundedBox 4, 0, 0, w, h, C.panel
	@BuildSidebar @Sidebar

	-- Canvas
	@CanvasHolder = parent\Add "DPanel"
	@CanvasHolder\SetZPos 0
	@BuildCanvas @CanvasHolder

	-- Layout: sidebar always visible, documents toggled
	@SidebarWidth = 260
	@DocumentWidth = 260

	parent.PerformLayout = (_, w, h) ->
		documentsVisible = Editor.DocumentsVisible
		sidebarWidth = Editor.SidebarWidth or 260
		docWidth = Editor.DocumentWidth or 260
		minimumCanvas = 420
		requiredWidth = sidebarWidth + minimumCanvas + (documentsVisible and docWidth or 0)
		compact = w < requiredWidth
		Editor.CompactLayout = compact

		if compact
			panelWidth = documentsVisible and docWidth or sidebarWidth
			Editor.FileDrawer\SetVisible documentsVisible
			Editor.Sidebar\SetVisible not documentsVisible
			Editor.CanvasHolder\SetPos 0, 0
			Editor.CanvasHolder\SetSize w, h
			if documentsVisible
				Editor.FileDrawer\SetPos 0, 0
				Editor.FileDrawer\SetSize math.min(panelWidth, w), h
				Editor.FileDrawer\MoveToFront!
			else
				Editor.Sidebar\SetPos 0, 0
				Editor.Sidebar\SetSize math.min(panelWidth, w), h
				Editor.Sidebar\MoveToFront!
		else
			x = 0
			Editor.FileDrawer\SetVisible documentsVisible
			Editor.Sidebar\SetVisible true
			if documentsVisible
				Editor.FileDrawer\SetPos x, 0
				Editor.FileDrawer\SetSize docWidth, h
				x += docWidth
			Editor.Sidebar\SetPos x, 0
			Editor.Sidebar\SetSize sidebarWidth, h
			x += sidebarWidth
			Editor.CanvasHolder\SetPos x, 0
			Editor.CanvasHolder\SetSize math.max(1, w - x), h

----
-- Editor open / init
----

Editor.Open = (surfaceKind = Moonpanel.Canvas.SurfaceKind.Flat) =>
	@SurfaceSpec = Moonpanel.Canvas.MakeSurfaceSpec surfaceKind, false
	if IsValid @Frame
		@Frame\SetVisible true
		@Frame\MakePopup!
		@Frame\MoveToFront!
		@SyncCanvas!
		return @Frame

	document = @EnsureDocument!
	_, loaded, metadata = document\LoadOnDemand!
	@OpenedFile = document\GetPath!

	@InitBrushes!

	@DocumentsVisible = false
	@SidebarWidth = 260

	minWidth, minHeight = math.min(900, ScrW! - 24), math.min(600, ScrH! - 24)
	width = math.Clamp(cookie and cookie.GetNumber("moonpanel_editor_w", math.floor(ScrW! * 0.92)) or math.floor(ScrW! * 0.92), minWidth, ScrW! - 24)
	height = math.Clamp(cookie and cookie.GetNumber("moonpanel_editor_h", math.floor(ScrH! * 0.92)) or math.floor(ScrH! * 0.92), minHeight, ScrH! - 24)

	@Frame = with vgui.Create "DFrame"
		\SetTitle "Moonpanel Editor"
		\SetSize width, height
		\SetSizable true
		\SetMinWidth math.min(760, ScrW! - 24)
		\SetMinHeight math.min(520, ScrH! - 24)
		\SetDraggable true
		\SetDeleteOnClose false
		\Center!
		\MakePopup!
		.Paint = (_, w, h) -> draw.RoundedBox 5, 0, 0, w, h, C.window
		.OnKeyCodePressed = (_, code) -> Editor\HandleKey code
		.OnSizeChanged = -> timer.Create "Moonpanel Editor Layout Save", 0.4, 1, -> Editor\SaveLayoutCookies!
		.OnClose = =>
			Moonpanel.Net.SendEditorClosed!
			Editor\ExitTestMode! if Editor.TestMode
			Editor\CanvasRelease!
			Editor\ScheduleRecovery! if Editor.Document and Editor.Document\IsDirty!
			Editor\SaveLayoutCookies!

	@TopBar = with @Frame\Add "DPanel"
		\Dock TOP
		\SetTall 40
		.Paint = (_, w, h) -> draw.RoundedBox 0, 0, 0, w, h, C.panel
	@BuildTopBar @TopBar

	@StatusBar = with @Frame\Add "DPanel"
		\Dock BOTTOM
		\SetTall 26
		.Paint = (_, w, h) -> draw.RoundedBox 0, 0, 0, w, h, C.panel
	@StatusLabel = with @StatusBar\Add "DLabel"
		\Dock FILL
		\DockMargin 10, 0, 10, 0
		\SetFont "MoonpanelEditorSmall"
		\SetTextColor C.muted
		\SetText @StatusText or "Ready"
		\SetContentAlignment 4

	@Body = with @Frame\Add "DPanel"
		\Dock FILL
		.Paint = nil
	@BuildBody @Body

	@SyncCanvas!
	if loaded and metadata and metadata.dirty then @SetStatus "Recovered unsaved work", C.warning
	else @SetStatus "Ready", C.muted
	@Frame

-- Legacy reference for old `BeginGesture` / `GestureActive` pattern used by canvas interaction
Editor.BeginGesture = (label) =>
	return if @GestureActive
	@Document\BeginEdit label
	@GestureActive = true

concommand.Add "moonpanel_editor", -> Moonpanel.Net.RequestEditorOpen!
