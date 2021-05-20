receive = Moonpanel.Net.Receive
flowTypes = Moonpanel.Net.FlowTypes
startFlow = Moonpanel.Net.StartFlow

------------------------------------------------
-- Tells everyone that the panel is now being --
-- controlled by the player in question.      --
------------------------------------------------
Moonpanel.Net.SendSolveStart = (panel, ply, nodeA, nodeB) ->
	startFlow flowTypes.PanelSolveStart

	net.WriteEntity panel
	net.WriteEntity ply
	net.WriteUInt nodeA, 16

    net.WriteBool not not nodeB
    if nodeB
        net.WriteUInt nodeB, 16

	net.Broadcast!

------------------------------------------------------
-- Tells everyone that the panel is no longer being --
-- controlled by someone.                           --
------------------------------------------------------
Moonpanel.Net.SendSolveStop = (panel) ->
	startFlow flowTypes.PanelSolveStop

	net.WriteEntity panel
	net.Broadcast!

----------------------------------------------------
-- Updates everyone except the chosen player with --
-- the new trace cursor value.                    --
----------------------------------------------------
Moonpanel.Net.BroadcastTraceUpdateCursor = (ply, panel, cursor) ->
    startFlow flowTypes.TraceUpdateCursor

    net.WriteEntity panel
    net.WriteUInt cursor, Moonpanel.Canvas.TraceCursorPrecision

    if IsValid ply
        net.SendOmit ply
    else
        net.Broadcast!

----------------------------------------------------
-- Updates everyone except the chosen player with --
-- the new trace potential node.                  --
----------------------------------------------------
Moonpanel.Net.BroadcastTraceUpdatePotential = (ply, panel, potentialNodes) ->
    startFlow flowTypes.TraceUpdatePotential

    net.WriteEntity panel
    net.WriteUInt #potentialNodes, 4
    for _, node in ipairs potentialNodes
        net.WriteFloat node.screenX
        net.WriteFloat node.screenY

    if IsValid ply
        net.SendOmit ply
    else
        net.Broadcast!

----------------------------------------------------
-- Updates everyone except the chosen player with --
-- the new nodes to push into their BA stacks.    --
----------------------------------------------------
Moonpanel.Net.BroadcastTracePushNodes = (ply, panel, nodeStacks) ->
    startFlow flowTypes.TracePushNodes

    net.WriteEntity panel
    net.WriteUInt #nodeStacks, 4
    for stackId, stack in ipairs nodeStacks
        net.WriteUInt #stack, 4
        for _, node in ipairs stack
            net.WriteFloat node.screenX
            net.WriteFloat node.screenY

    if IsValid ply
        net.SendOmit ply
    else
        net.Broadcast!

----------------------------------------------------
-- Updates everyone except the chosen player with --
-- the list number of nodes they need to pop from --
-- their BA stacks.                               --
----------------------------------------------------
Moonpanel.Net.BroadcastTracePopNodes = (ply, panel, pops) ->
	startFlow flowTypes.TracePopNodes

    net.WriteEntity panel
    net.WriteUInt #pops, 4
    for _, pop in ipairs pops
        net.WriteUInt pop, 4

    if IsValid ply
        net.SendOmit ply
    else
        net.Broadcast!

----------------------------------------------------
-- Updates everyone except the chosen player with --
-- the new trace touching-exit-state.             --
----------------------------------------------------
Moonpanel.Net.BroadcastTraceTouchingExit = (ply, panel, state) ->
    startFlow flowTypes.TraceTouchingExit

    net.WriteEntity panel
    net.WriteBool state == true

    if IsValid ply
        net.SendOmit ply
    else
        net.Broadcast!

------------------------------------
-- Dispatches panel data packets. --
------------------------------------
Moonpanel.Net.SendPanelData = (ply, panel, data) ->
    startFlow flowTypes.PanelRequestData

    net.WriteEntity panel
    net.WriteTable data
    net.Send ply

-----------------------------------
-- Broadcasts ending animations. --
-----------------------------------
Moonpanel.Net.BroadcastEndingAnimation = (panel, data) ->
    startFlow flowTypes.PanelEndingAnimation

    net.WriteEntity panel
    net.WriteTable data
    net.Broadcast!

-------------------------------------------------------
-- Creates a client->server panel data request.      --
-- Sweeps invalid requests so we don't end up having --
-- leaks from endless unfulfilled requests.          --
-------------------------------------------------------
Moonpanel.Net.PanelRequestDataFromPlayer = (ply, panel, callback) ->
    -- Sweep old requests.
    for panel, data in pairs Moonpanel.Net.PendingPlayerDataRequests
        if not (IsValid panel) or not (IsValid data.ply)
            Moonpanel.Net.PendingPlayerDataRequests[panel] = nil

	Moonpanel.Net.PendingPlayerDataRequests[panel] = {
        :ply
        :callback
    }

Moonpanel.Net.PendingPlayerDataRequests or= {}

--------------------------------------------
-- Receive control requests from players. --
--------------------------------------------
receive flowTypes.PanelRequestControl, (len, ply) ->
	Moonpanel\RequestControl ply, net.ReadEntity!,
		(net.ReadUInt 16), net.ReadUInt 16

----------------------------------------
-- Receive panel deltas from players. --
----------------------------------------
receive flowTypes.TraceDeltas, (len, ply) ->
	dX = net.ReadInt 8
	dY = net.ReadInt 8

	Moonpanel\ApplyDeltas ply, dX, dY

---------------------------------------------------------
-- Receive panel data update requests from players and --
-- tell players to supply the actual data once we've   --
-- confirmed that the panel exists on their side.      --
---------------------------------------------------------
receive flowTypes.PanelRequestData, (len, ply) ->
	entity = net.ReadEntity!
    return unless (IsValid entity) and entity.Moonpanel and entity.GetCanvas

    -- If there's a pending client->server data request,
    -- ask the player to fulfill it.
    request = Moonpanel.Net.PendingPlayerDataRequests[entity]
    if request and request.ply == ply
        startFlow flowTypes.PanelRequestDataFromPlayer
        net.WriteEntity entity
        net.Send ply

    entity\SyncPlayer ply

----------------------------------------------------------
-- Receive panel datas from players and apply to panels --
-- in case there's a pending update.                    --
----------------------------------------------------------
receive flowTypes.PanelRequestDataFromPlayer, (len, ply) ->
	entity = net.ReadEntity!
    request = Moonpanel.Net.PendingPlayerDataRequests[entity]

    return unless request
    return unless (IsValid entity) and entity.Moonpanel and entity.GetCanvas

    data = net.ReadTable! or {}
    return if not data or not istable data

    request.callback data
