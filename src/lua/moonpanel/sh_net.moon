if SERVER
	AddCSLuaFile!
	AddCSLuaFile "cl_net.lua"
	util.AddNetworkString "TheMP Flow"

Moonpanel.Net or= {}

Moonpanel.Net.FlowTypes = {
	"TraceControlGrant"
	"TraceControlReject"
	"TraceInputBatch"
	"TraceObserverAdvance"
	"TraceAck"
	"TraceResyncSnapshot"
	"TraceAction"
	"TraceResult"
	"FocusExit"

	"PanelRequestData"
	"PanelResetPresentation"
	"PanelRequestDataFromPlayer"
	"PanelRequestControl"
	"TraceVisualResult"
	"EditorOpen"
	"EditorStatus"
}

-- Determine the smallest packet required to fit the flowtypes enum.
Moonpanel.Net.FlowSize = math.ceil(math.log(#Moonpanel.Net.FlowTypes, 2))

-- Turn the flowtypes array into a map/enum.
flowTypes = Moonpanel.Net.FlowTypes
Moonpanel.Net.FlowTypes = {v, k - 1 for k, v in ipairs flowTypes}
Moonpanel.Net.Receivers = {}
Moonpanel.Net.TraceControlRejectReasons = {
	unknown: 0
	busy: 1
	ending: 2
	notFocused: 3
	notPlayable: 4
	invalidStart: 5
	tooFar: 6
	dead: 7
	notPowered: 8
}

net.Receive "TheMP Flow", (len, ply) ->
	flowType = net.ReadUInt Moonpanel.Net.FlowSize
	callback = Moonpanel.Net.Receivers[flowType]

	callback len, ply if callback

Moonpanel.Net.Receive = (flowType, callback) ->
	Moonpanel.Net.Receivers[flowType] = callback

Moonpanel.Net.StartFlow = (flowType) ->
	net.Start "TheMP Flow"
	net.WriteUInt flowType, Moonpanel.Net.FlowSize

Moonpanel.Net.TraceBatchMax = 12
Moonpanel.Net.TraceConstraintMax = 2

Moonpanel.Net.WriteTraceSamples = (samples, count = #samples) ->
	net.WriteUInt count, 4
	for index = 1, count
		sample = samples[index]
		net.WriteInt sample.xQ, 16
		net.WriteInt sample.yQ, 16
		net.WriteBool sample.boost
		net.WriteUInt sample.commandNumber or 0, 32
		net.WriteUInt #sample.constraints, 2
		net.WriteUInt decision, 32 for decision in *sample.constraints

Moonpanel.Net.ReadTraceSamples = ->
	count = net.ReadUInt 4
	samples, malformed = {}, count < 1 or count > Moonpanel.Net.TraceBatchMax
	for index = 1, count
		xQ, yQ = net.ReadInt(16), net.ReadInt(16)
		malformed = true if xQ == -32768 or yQ == -32768
		boost, commandNumber = net.ReadBool!, net.ReadUInt(32)
		constraintCount = net.ReadUInt 2
		malformed = true if constraintCount > Moonpanel.Net.TraceConstraintMax
		constraints = [net.ReadUInt(32) for _ = 1, constraintCount]
		samples[index] = { :xQ, :yQ, :boost, :commandNumber, :constraints }
	samples, count, malformed

include if SERVER
	"sv_net.lua"
else
	"cl_net.lua"
