if SERVER
	AddCSLuaFile!
	AddCSLuaFile "cl_net.lua"
	util.AddNetworkString "TheMP Flow"

Moonpanel.Net or= {}

Moonpanel.Net.FlowTypes = {
	"TraceDeltas"
	"TracePushNodes"
    "TracePopNodes"
    "TraceUpdateCursor"
    "TraceUpdatePotential"
    "TraceTouchingExit"

	"PanelRequestData"
	"PanelRequestDataFromPlayer"
	"PanelRequestControl"
	"PanelSolveStart"
	"PanelSolveStop"
	"PanelEndingAnimation"
}

-- Determine the smallest packet required to fit the flowtypes enum.
Moonpanel.Net.FlowSize = math.ceil(math.log(#Moonpanel.Net.FlowTypes, 2))

-- Turn the flowtypes array into a map/enum.
flowTypes = Moonpanel.Net.FlowTypes
Moonpanel.Net.FlowTypes = {v, k - 1 for k, v in pairs flowTypes}
Moonpanel.Net.Receivers = {}

net.Receive "TheMP Flow", (len, ply) ->
	flowType = net.ReadUInt Moonpanel.Net.FlowSize
	callback = Moonpanel.Net.Receivers[flowType]

	callback len, ply if callback

Moonpanel.Net.Receive = (flowType, callback) ->
	Moonpanel.Net.Receivers[flowType] = callback

Moonpanel.Net.StartFlow = (flowType) ->
	net.Start "TheMP Flow"
	net.WriteUInt flowType, Moonpanel.Net.FlowSize

include if SERVER
	"sv_net.lua"
else
	"cl_net.lua"
