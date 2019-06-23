export Moonpanel = {}

Moonpanel.setFocused = (player, state, force) =>
    time = player.themp_lastfocuschange or 0

    if force or (CurTime! >= time and state ~= player\GetNW2Bool "TheMP Focused")
        if (state ~= player\GetNW2Bool "TheMP Focused")
            if state
                weap = player\GetActiveWeapon!
                if IsValid weap
                    player.themp_oldweapon = weap\GetClass!
                if not player\HasWeapon "none"
                    player\Give "none"
                    player.themp_givenhands = true
            else
                player\SetNW2Entity "TheMP Controlled Panel", nil
                player\SelectWeapon player.themp_oldweapon or "none"
                if player.themp_givenhands
                    player.themp_givenhands = false
                    player\StripWeapon "none"

        player\SetNW2Bool "TheMP Focused", state

        player.themp_lastfocuschange = CurTime! + 0.75

Moonpanel.requestControl = (ply, ent, x, y) =>
    if ply\GetNW2Entity("TheMP Controlled Panel") == ent
        ent\FinishPuzzle x, y
        ply\SetNW2Entity "TheMP Controlled Panel", nil
    else
        if ent\StartPuzzle ply, x, y
            ply\SetNW2Entity "TheMP Controlled Panel", ent

hook.Add "KeyPress", "TheMP Focus", (ply, key) ->
    if key == IN_USE
        Moonpanel\setFocused ply, false

hook.Add "Think", "TheMP Think", () ->
    for k, v in pairs player.GetAll!
        if v\GetNW2Bool "TheMP Focused"
            v\SelectWeapon "none"

hook.Add "PostPlayerDeath", "TheMP PlayerDeath", (ply) ->
    Moonpanel\setFocused ply, false, true

hook.Add "PlayerSilentDeath", "TheMP PlayerDeath", (ply) ->
    Moonpanel\setFocused ply, false, true

net.Receive "TheMP Request Control", (len, ply) ->
    ent = net.ReadEntity!
    x = net.ReadUInt 10
    y = net.ReadUInt 10

    Moonpanel\requestControl ply, ent, x, y

net.Receive "TheMP Mouse Deltas", (len, ply) ->
    if IsValid ply\GetNW2Entity("TheMP Controlled Panel")
        x = net.ReadFloat!
        y = net.ReadFloat!

        print x, y