receive = Moonpanel.Net.Receive
flowTypes = Moonpanel.Net.FlowTypes
startFlow = Moonpanel.Net.StartFlow

---------------------------------------------------------
-- Tells the server that we want to control the panel. --
---------------------------------------------------------
Moonpanel.Net.PanelRequestControl = (entity, x = 0, y = 0) ->
	startFlow flowTypes.PanelRequestControl

	net.WriteEntity entity
	net.WriteUInt x, 16
	net.WriteUInt y, 16
	net.SendToServer!

---------------------------------------
-- Sends trace deltas to the server. --
---------------------------------------
Moonpanel.Net.SendDeltas = (x = 0, y = 0) ->
	startFlow flowTypes.TraceDeltas

	net.WriteInt x, 8
	net.WriteInt y, 8
	net.SendToServer!

-------------------------------------------------------
-- Creates a server->client panel data request.      --
-------------------------------------------------------
Moonpanel.Net.PanelRequestData = (panel, callback) ->
	Moonpanel.Net.PendingPanelDataRequests[panel] = callback

	startFlow flowTypes.PanelRequestData

	net.WriteEntity panel
	net.SendToServer!

Moonpanel.Net.PendingPanelDataRequests or= {}

-------------------------------------------------
-- Receive client->server panel data requests. --
-------------------------------------------------
receive flowTypes.PanelRequestDataFromPlayer, ->
	entity = net.ReadEntity!
    return unless entity.Moonpanel and entity.GetCanvas

	startFlow flowTypes.PanelRequestDataFromPlayer
	net.WriteEntity entity
	net.WriteTable Moonpanel.Canvas.SanitizeData Moonpanel.Canvas.SampleData
	net.SendToServer!

------------------------------------------------
-- Receive server->client panel data updates. --
------------------------------------------------
receive flowTypes.PanelRequestData, ->
	panel = net.ReadEntity!

	return if not IsValid panel

	if callback = Moonpanel.Net.PendingPanelDataRequests[panel]
		data = net.ReadTable!
		callback panel, data

--------------------------------
-- Receive panel game starts. --
--------------------------------
receive flowTypes.PanelSolveStart, ->
	panel = net.ReadEntity!
	return if not (IsValid panel) or not panel.IsSynchonized or
		not panel\IsSynchonized!

	ply = net.ReadEntity!
	nodeId = net.ReadUInt 16

	panel\SolveStart ply, nodeId

-------------------------------
-- Receive panel game stops. --
-------------------------------
receive flowTypes.PanelSolveStop, ->
	panel = net.ReadEntity!
	return if not (IsValid panel) or not panel.IsSynchonized or
		not panel\IsSynchonized!

	panel\SolveStop ply

---------------------------------
-- Receive panel ending anims. --
---------------------------------
receive flowTypes.PanelEndingAnimation, ->
	panel = net.ReadEntity!
	return if not (IsValid panel) or not panel.IsSynchonized or
		not panel\IsSynchonized!

	panel\PlayEndingAnimation net.ReadTable!

--------------------------------------
-- Receive BA cursor value updates. --
--------------------------------------
receive flowTypes.TraceUpdateCursor, ->
	panel = net.ReadEntity!
	return if not (IsValid panel) or not panel.IsSynchonized or
		not panel\IsSynchonized!

	cursor = net.ReadUInt Moonpanel.Canvas.TraceCursorPrecision

	panel\GetCanvas!\UpdateTraceCursor cursor / (2 ^ Moonpanel.Canvas.TraceCursorPrecision)

-----------------------------------
-- Receive new BA nodes to push. --
-----------------------------------
receive flowTypes.TracePushNodes, ->
	panel = net.ReadEntity!
	return if not (IsValid panel) or not panel.IsSynchonized or
		not panel\IsSynchonized!

	nodeStacks = net.ReadUInt 4
	for stackId = 1, nodeStacks
		nodes = net.ReadUInt 4
		for nodeId = 1, nodes
			screenX, screenY = net.ReadFloat!, net.ReadFloat!

			panel\GetCanvas!\TracePushNode stackId, screenX, screenY

-------------------------------------
-- Receive new BA potential nodes. --
-------------------------------------
receive flowTypes.TraceUpdatePotential, ->
	panel = net.ReadEntity!
	return if not (IsValid panel) or not panel.IsSynchonized or
		not panel\IsSynchonized!

	nodeStacks = net.ReadUInt 4
	for stackId = 1, nodeStacks
		screenX, screenY = net.ReadFloat!, net.ReadFloat!

		panel\GetCanvas!\TracePotentialNode stackId, screenX, screenY

-----------------------------------------
-- Receive amounts of BA nodes to pop. --
-----------------------------------------
receive flowTypes.TracePopNodes, ->
	panel = net.ReadEntity!
	return if not (IsValid panel) or not panel.IsSynchonized or
		not panel\IsSynchonized!

	pops = net.ReadUInt 4
	for i = 1, pops
		amount = net.ReadUInt 4

		for pop = 1, amount
			panel\GetCanvas!\TracePopNode i

---------------------------------------------
-- Receive BA exit touching notifications. --
---------------------------------------------
receive flowTypes.TraceTouchingExit, ->
	panel = net.ReadEntity!
	return if not (IsValid panel) or not panel.IsSynchonized or
		not panel\IsSynchonized!

	state = net.ReadBool!

	panel\GetCanvas!\TraceUpdateTouchingExit state
