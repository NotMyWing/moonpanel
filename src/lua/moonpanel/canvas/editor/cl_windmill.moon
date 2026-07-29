return unless CLIENT

Moonpanel.Editor or= {}
Editor = Moonpanel.Editor
Canvas = Moonpanel.Canvas
C = Editor.C

WINDMILL_HOME = "https://windmill.thefifthmatt.com/"
Editor.WindmillProxyEndpoint = CreateClientConVar(
	"moonpanel_windmill_proxy",
	"https://windmill-proxy.pony.workers.dev/",
	true,
	false,
	"The proxy used to import puzzles from The Windmill."
)

windmillPath = (value) ->
	value = string.Trim tostring(value or "")
	path = string.match value, "^https?://windmill%.thefifthmatt%.com/(.+)$"
	path or= string.match value, "^https?://www%.windmill%.thefifthmatt%.com/(.+)$"
	return unless path

	-- DHTML may include a query string or fragment after the puzzle path.
	path = string.gsub path, "[?#].*$", ""
	path = string.gsub path, "^/+", ""
	path if path ~= ""

Editor.ApplyWindmillData = (data) =>
	return unless data
	@ExitTestMode! if @TestMode
	@WithDirtyGuard ->
		@Document\Replace data, resetHistory: true, clearPath: true
		@RefreshBrushValidity!
		@SyncCanvas!
		@ScheduleRecovery!
		@SetStatus "Imported The Windmill puzzle", C.success
		-- Keep the reusable importer alive. Closing a DHTML frame can leave its
		-- browser control in a stale state, which makes subsequent imports fail.
		frame = @WindmillFrame
		frame\SetVisible false if IsValid frame

Editor.FetchWindmill = (url) =>
	path = windmillPath url
	unless path
		@SetStatus "Use a The Windmill puzzle URL.", C.danger
		return

	@SetStatus "Fetching The Windmill puzzle...", C.muted
	editor = @
	endpoint = Editor.WindmillProxyEndpoint\GetString!
	fetchError = (fetchError) ->
		editor\SetStatus fetchError or "Failed to fetch the Windmill puzzle.", C.danger
	fetchSuccess = (body, length, headers, code) ->
		result = util.JSONToTable body or ""
		data, error = Canvas.WindmillToCanvasData result
		unless data
			editor\SetStatus error or "Failed to decode the Windmill puzzle.", C.danger
			return
		editor\ApplyWindmillData data
	http.Fetch endpoint .. path, fetchSuccess, fetchError

Editor.ShowWindmillImporter = =>
	if IsValid @WindmillFrame
		frame = @WindmillFrame
		address = @WindmillAddress
		html = @WindmillHTML
		address\SetText WINDMILL_HOME if IsValid address
		html\OpenURL WINDMILL_HOME if IsValid html
		frame\SetVisible true
		frame\MakePopup!
		frame\MoveToFront!
		return

	@WindmillFrame = with vgui.Create "DFrame"
		\SetTitle "Import from The Windmill"
		\SetSize math.min(ScrW! * 0.7, 980), math.min(ScrH! * 0.75, 720)
		\SetMinWidth 640
		\SetMinHeight 420
		\Center!
		\SetDeleteOnClose false
		\MakePopup!

	nav = with @WindmillFrame\Add "DPanel"
		\Dock TOP
		\DockMargin 6, 6, 6, 4
		\SetTall 32
		.Paint = nil

	html = nil
	address = with nav\Add "DTextEntry"
		\Dock FILL
		\DockMargin 0, 0, 6, 0
		\SetText WINDMILL_HOME
		\SetUpdateOnType false
		.OnEnter = -> html\OpenURL address\GetValue!

	open = with nav\Add "DButton"
		\Dock RIGHT
		\SetWide 72
		\SetText ""
		.DoClick = -> html\OpenURL address\GetValue!
		.Paint = (_, w, h) ->
			draw.RoundedBox 4, 0, 0, w, h, _.Hovered and C.hover or C.raised
			draw.SimpleText "Open", "MoonpanelEditorSmall", w / 2, h / 2, C.text,
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
	Editor\AttachTextTooltip open, "Open this Windmill URL"

	importButton = with nav\Add "DButton"
		\Dock RIGHT
		\SetWide 82
		\SetText ""
		.DoClick = -> Editor\FetchWindmill address\GetValue!
		.Paint = (_, w, h) ->
			draw.RoundedBox 4, 0, 0, w, h, _.Hovered and C.accent or C.accentDim
			draw.SimpleText "Import", "MoonpanelEditorSmall", w / 2, h / 2, C.text,
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
	Editor\AttachTextTooltip importButton, "Import the puzzle at this URL"

	hrefCallback = (newHref) -> address\SetText newHref
	html = with @WindmillFrame\Add "DHTML"
		\Dock FILL
		\DockMargin 6, 0, 6, 6
		.OnBeginLoadingDocument = (_, url) -> address\SetText url
		.OnFinishLoadingDocument = ->
			html\AddFunction "moonpanelWindmill", "hrefChanged", hrefCallback
			html\Call [[
				(function () {
					var oldHref = null;
					setInterval(function () {
						if (window.location.href != oldHref) {
							moonpanelWindmill.hrefChanged(window.location.href);
							oldHref = window.location.href;
						}
					}, 500);
				})();
			]]
		\OpenURL WINDMILL_HOME

	@WindmillAddress = address
	@WindmillHTML = html
