AddCSLuaFile "cl_init.lua"
AddCSLuaFile "shared.lua"
include "shared.lua"

ENT.InitializeSided = =>
    @PhysicsInit            SOLID_VPHYSICS
    @SetMoveType            MOVETYPE_VPHYSICS
    @SetSolid               SOLID_VPHYSICS
    @SetUseType             SIMPLE_USE
    @AddEFlags              EFL_FORCE_CHECK_TRANSMIT

    panelSoundLevel = 65
    @Sounds = {
        Scint:    with CreateSound @, "moonpanel/panel_scint.ogg"
            \SetSoundLevel panelSoundLevel

        Failure:  with CreateSound @, "moonpanel/panel_failure.ogg"
            \SetSoundLevel panelSoundLevel

        PotentialFailure: with CreateSound @, "moonpanel/panel_potential_failure.ogg"
            \SetSoundLevel panelSoundLevel

        Success:  with CreateSound @, "moonpanel/panel_success.ogg"
            \SetSoundLevel panelSoundLevel

        Start:    with CreateSound @, "moonpanel/panel_start_tracing.ogg"
            \SetSoundLevel panelSoundLevel

        Eraser:   with CreateSound @, "moonpanel/eraser_apply.ogg"
            \SetSoundLevel panelSoundLevel

        Abort:    with CreateSound @, "moonpanel/panel_abort_tracing.ogg"
            \SetSoundLevel panelSoundLevel

        PowerOn:  with CreateSound @, "moonpanel/powered_on.ogg"
            \SetSoundLevel panelSoundLevel

        PowerOff: with CreateSound @, "moonpanel/powered_off.ogg"
            \SetSoundLevel panelSoundLevel

        PathComplete: with CreateSound @, "moonpanel/panel_path_complete_loop.wav"
            \SetSoundLevel 45

        SolvingLoop: with CreateSound @, "moonpanel/panel_solving_loop.wav"
            \SetSoundLevel 40

        PresenceLoop: with CreateSound @, "moonpanel/panel_presence_loop.wav"
            \SetSoundLevel 40

        FinishTracing: with CreateSound @, "moonpanel/panel_finish_tracing.ogg"
            \SetSoundLevel panelSoundLevel

        AbortFinishTracing: with CreateSound @, "moonpanel/panel_abort_finish_tracing.ogg"
            \SetSoundLevel panelSoundLevel
    }

    @__syncedPlayers = {}
    @__pendingSyncs = {}

ENT.SetData = (data) =>
    canvas = @GetCanvas!
    canvas\SetData data
    canvas\RebuildNodes!
    canvas\InitPathFinder!

    @SetPowered true

    @ExecutePendingSyncs!

ENT.ExecutePendingSyncs = =>
    for ply in pairs @__pendingSyncs
        @SyncPlayer ply

    @__pendingSyncs = nil

ENT.SyncPlayer = (ply) =>
    canvas = @GetCanvas!

    if not canvas or not canvas\GetData!
        @__pendingSyncs[ply] = true
        return

    return if not canvas

    return if @__syncedPlayers[ply]
    @__syncedPlayers[ply] = true

    data = {
        panelData: canvas\ExportData!
        playData: canvas\ExportPlayData!
    }

	Moonpanel.Net.SendPanelData ply, @, data

ENT.RequestDataFromPlayer = (ply) =>
    Moonpanel.Net.PanelRequestDataFromPlayer ply, @, (data) ->
        @SetData data

ENT.PlaySound = (sound, volume = 1, pitch = 100) =>
    if sound\IsPlaying!
        sound\Stop!

    sound\PlayEx volume, pitch

ENT.RequestControl = (ply, x, y) =>
    return if IsValid @GetController!

    pathfinder = @__canvas\GetPathFinder!
    return if not pathfinder

    node = pathfinder\getClosestNode x, y, 32
    return if not node

    @SolveStart ply, node.id

ENT.StopControl = (ply) =>
    return if not IsValid @GetController!

    @PlaySound @Sounds.Abort
    @Sounds.SolvingLoop\Stop!

    @SetController nil
    @SolveStop!

ENT.UpdateTransmitState = =>
	TRANSMIT_ALWAYS

ENT.OnRemove = =>
    Moonpanel\StopControl @GetController! if IsValid @GetController!

    for _, sound in pairs @Sounds
        sound\Stop!
