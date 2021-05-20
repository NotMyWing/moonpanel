AddCSLuaFile "cl_init.lua"
AddCSLuaFile "shared.lua"
include "shared.lua"

ENT.InitializeSided = =>
    @PhysicsInit            SOLID_VPHYSICS
    @SetMoveType            MOVETYPE_VPHYSICS
    @SetSolid               SOLID_VPHYSICS
    @SetUseType             SIMPLE_USE
    @AddEFlags              EFL_FORCE_CHECK_TRANSMIT

    @__syncedPlayers = {}
    @__pendingSyncs = {}

ENT.SetData = (data) =>
    canvas = @GetCanvas!
    canvas\ImportData data

    @SetPowered true

    @ExecutePendingSyncs!

ENT.ExecutePendingSyncs = =>
    return if not @__pendingSyncs

    for ply in pairs @__pendingSyncs
        @SyncPlayer ply

    @__pendingSyncs = nil

ENT.SyncPlayer = (ply) =>
    canvas = @GetCanvas!

    if not canvas or not canvas\GetData!
        @__pendingSyncs[ply] = true
        return

    return if not canvas

    --return if @__syncedPlayers[ply]
    -- @__syncedPlayers[ply] = true

    data = {
        panelData: canvas\ExportData!
        playData: canvas\ExportPlayData!
    }

	Moonpanel.Net.SendPanelData ply, @, data

ENT.RequestDataFromPlayer = (ply) =>
    Moonpanel.Net.PanelRequestDataFromPlayer ply, @, (data) ->
        @SetData data

ENT.RequestControl = (ply, x, y) =>
    return if IsValid @GetController!

    canvas = @GetCanvas!

    pathfinder = canvas\GetPathFinder!
    return if not pathfinder

    node = pathfinder\getClosestNode x, y, 32
    return if not node

    result = @SolveStart ply, node.id
    if result
        canvas\PlaySound "SolvingLoop"

    result

ENT.StopControl = (ply) =>
    return if not IsValid @GetController!

    canvas = @GetCanvas!
    canvas\StopSound "SolvingLoop"

    @SetController nil
    @SolveStop!

ENT.UpdateTransmitState = =>
	TRANSMIT_ALWAYS
