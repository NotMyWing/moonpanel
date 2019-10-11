Moonpanel.sendMouseDeltas = (x, y) =>
    net.Start "TheMP Flow"
    net.WriteUInt Moonpanel.Flow.ApplyDeltas, 8

    net.WriteInt x, 8
    net.WriteInt y, 8
    net.SendToServer!

Moonpanel.requestControl = (ent, x, y) =>
    net.Start "TheMP Flow"
    net.WriteUInt Moonpanel.Flow.RequestControl, 8

    net.WriteEntity ent
    net.WriteUInt x, 10
    net.WriteUInt y, 10
    net.SendToServer!

Moonpanel.requestData = (ent) =>
    net.Start "TheMP Flow"
    net.WriteUInt Moonpanel.Flow.RequestData, 8

    net.WriteEntity ent
    net.SendToServer!

Moonpanel.getControlledPanel = () =>
    panel = LocalPlayer!\GetNW2Entity "TheMP Controlled Panel"
    return panel

net.Receive "TheMP Editor", () ->
    Moonpanel.editor\Show! 
    Moonpanel.editor\MakePopup!

net.Receive "TheMP NodeStacks", (len) ->
    stacks, curs = {}, {}

    panel = net.ReadEntity!
    if IsValid panel
        return

    stackCount = net.ReadUInt 4
    for i = 1, stackCount
        pointCount = net.ReadUInt 10
        stack = {}
        for j = 1, pointCount
            stack[#stack + 1] = {
                x: net.ReadUInt 10
                y: net.ReadUInt 10
            }

        stacks[#stacks + 1] = stack

    curCount = net.ReadUInt 4
    for i = 1, curCount
        curs[#curs + 1] = {
            x: net.ReadUInt 10
            y: net.ReadUInt 10
        }

    panel.shouldRepaintTrace = true

net.Receive "TheMP EditorData Req", () ->
    data = "{}"

    if Moonpanel.editor
        data = util.Compress util.TableToJSON Moonpanel.editor\Serialize!

    net.Start "TheMP EditorData"
    net.WriteUInt #data, 32
    net.WriteData data, #data
    net.SendToServer!
 
net.Receive "TheMP Flow", () ->
    flowType = net.ReadUInt 8
    panel = net.ReadEntity!

    if not IsValid panel
        return

    switch flowType
        when Moonpanel.Flow.PuzzleStart
            if not panel.Moonpanel or not panel.synchronized
                return

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
                    panel\PuzzleStart nodeA, nodeB
        
        when Moonpanel.Flow.ApplyDeltas
            if not panel.Moonpanel or not panel.synchronized
                return

            x, y = net.ReadInt(8), net.ReadInt(8)

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

net.Receive "TheMP Notify", () ->
    message = net.ReadString!
    sound = net.ReadString!
    type = net.ReadUInt 8

    if GAMEMODE and GAMEMODE.AddNotify
        GAMEMODE\AddNotify message, type, 5
    elseif notification.AddLegacy
        notification.AddLegacy message, type, 5
    surface.PlaySound sound

if Moonpanel.__initialized
    Moonpanel\init!