Moonpanel.sendMouseDeltas = (x, y) =>
    net.Start "TheMP Flow"
    net.WriteUInt Moonpanel.Flow.ApplyDeltas, Moonpanel.FlowSize

    net.WriteFloat x
    net.WriteFloat y
    net.SendToServer!

Moonpanel.requestControl = (ent, x, y) =>
    net.Start "TheMP Flow"
    net.WriteUInt Moonpanel.Flow.RequestControl, Moonpanel.FlowSize

    net.WriteEntity ent
    net.WriteUInt x, 10
    net.WriteUInt y, 10
    net.SendToServer!

Moonpanel.requestData = (ent) =>
    net.Start "TheMP Flow"
    net.WriteUInt Moonpanel.Flow.RequestData, Moonpanel.FlowSize

    net.WriteEntity ent
    net.SendToServer!

Moonpanel.getControlledPanel = () =>
    panel = LocalPlayer!\GetNW2Entity "TheMP Controlled Panel"
    return panel

net.Receive "TheMP Editor", () ->
    Moonpanel.editor\Show! 
    Moonpanel.editor\MakePopup!

net.Receive "TheMP EditorData Req", () ->
    data = "{}"

    if Moonpanel.editor
        data = util.Compress util.TableToJSON Moonpanel.editor\Serialize!

    net.Start "TheMP EditorData"
    net.WriteUInt #data, 32
    net.WriteData data, #data
    net.SendToServer!
 
net.Receive "TheMP Flow", () ->
    flowType = net.ReadUInt Moonpanel.FlowSize
    panel = net.ReadEntity!

    if not IsValid panel
        return

    switch flowType
        when Moonpanel.Flow.PuzzleStart
            if not panel.Moonpanel or not panel.synchronized
                return

            user = net.ReadEntity!

            _nodeA, _nodeB = {
                x: net.ReadFloat!
                y: net.ReadFloat!
            }, nil
            if net.ReadBool!
                _nodeB = {
                    x: net.ReadFloat!
                    y: net.ReadFloat!
                }

            if IsValid(panel) and panel.pathFinder
                nodeA, nodeB = nil, nil
                if _nodeA
                    for _, node in pairs panel.pathFinder.nodeMap
                        if node.x == _nodeA.x and node.y == _nodeA.y
                            nodeA = node
                            break

                if _nodeB
                    for _, node in pairs panel.pathFinder.nodeMap
                        if node.x == _nodeB.x and node.y == _nodeB.y
                            nodeB = node
                            break

                if nodeA
                    panel\PuzzleStart user, nodeA, nodeB
        
        when Moonpanel.Flow.ApplyDeltas
            if not panel.Moonpanel or not panel.synchronized
                return

            x, y = net.ReadFloat!, net.ReadFloat!

            panel\ApplyDeltas x, y

        when Moonpanel.Flow.PuzzleFinish
            if not panel.Moonpanel or not panel.synchronized
                return

            len = net.ReadUInt 32
            data = util.JSONToTable(util.Decompress(net.ReadData(len)) or "{}") or {}

            panel\PuzzleFinish data

        when Moonpanel.Flow.PanelData
            if not panel.Moonpanel or panel.synchronized
                return

            length = net.ReadUInt 32
            raw = net.ReadData length

            data = util.JSONToTable((util.Decompress raw) or "{}") or {}

            panel\SetupData data

        when Moonpanel.Flow.Desync
            if not panel.Moonpanel
                return

            panel.synchronized = false

        when Moonpanel.Flow.UpdateCursor
            if not panel.Moonpanel or not panel.synchronized
                return

            precision = Moonpanel.TraceCursorPrecision
            cursor = net.ReadUInt precision

            panel\UpdateTraceCursor cursor / (2 ^ precision)

        when Moonpanel.Flow.PushNodes
            if not panel.Moonpanel or not panel.synchronized
                return

            nodeStacks = net.ReadUInt 4
            for stackId = 1, nodeStacks
                nodes = net.ReadUInt 4
                for nodeId = 1, nodes
                    screenX, screenY = net.ReadFloat!, net.ReadFloat!

                    panel\TracePushNode stackId, screenX, screenY
        
        when Moonpanel.Flow.UpdatePotential
            if not panel.Moonpanel or not panel.synchronized
                return

            nodeStacks = net.ReadUInt 4
            for stackId = 1, nodeStacks
                screenX, screenY = net.ReadFloat!, net.ReadFloat!

                panel\TracePotentialNode stackId, screenX, screenY

        when Moonpanel.Flow.PopNodes
            if not panel.Moonpanel or not panel.synchronized
                return

            pops = net.ReadUInt 4
            for i = 1, pops
                amount = net.ReadUInt 4

                for pop = 1, amount
                    panel\TracePopNode i

        when Moonpanel.Flow.TouchingExit
            if not panel.Moonpanel or not panel.synchronized
                return

            state = net.ReadBool!

            panel\UpdateTouchingExit state


net.Receive "TheMP Notify", () ->
    message = net.ReadString!
    sound = net.ReadString!
    type = net.ReadUInt 8

    if GAMEMODE and GAMEMODE.AddNotify
        GAMEMODE\AddNotify message, type, 5
    elseif notification.AddLegacy
        notification.AddLegacy message, type, 5
    surface.PlaySound sound

net.Receive "TheMP Reload", ->
    timer.Simple 0, ->
        include "autorun/moonpanel.lua"
        return
