-- Owns trace-session records separately from panel entities. Panels keep the
-- lifecycle relationship; this registry keeps the session data.

Moonpanel.TraceSession or= {}
Moonpanel.TraceSession.Active or= setmetatable {}, __mode: "k"
Moonpanel.TraceSession.Ending or= setmetatable {}, __mode: "k"
Moonpanel.TraceSession.NextId = Moonpanel.TraceSession.NextId or 0

Moonpanel.TraceSession.Create = (panel, data = {}) ->
	Moonpanel.TraceSession.NextId = (Moonpanel.TraceSession.NextId + 1) % 4294967295
	Moonpanel.TraceSession.NextId = 1 if Moonpanel.TraceSession.NextId == 0
	data.id = Moonpanel.TraceSession.NextId
	data.panel = panel
	data

Moonpanel.TraceSession.Get = (panel) ->
	Moonpanel.TraceSession.Active[panel]

Moonpanel.TraceSession.Set = (panel, session) ->
	if session
		Moonpanel.TraceSession.Active[panel] = session
	else
		Moonpanel.TraceSession.Active[panel] = nil
	session

Moonpanel.TraceSession.GetEnding = (panel) ->
	Moonpanel.TraceSession.Ending[panel]

Moonpanel.TraceSession.SetEnding = (panel, session) ->
	if session
		Moonpanel.TraceSession.Ending[panel] = session
	else
		Moonpanel.TraceSession.Ending[panel] = nil
	session

Moonpanel.TraceSession.ClearEnding = (panel, session = nil) ->
	ending = Moonpanel.TraceSession.Ending[panel]
	Moonpanel.TraceSession.Ending[panel] = nil if not session or ending == session
