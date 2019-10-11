hook.Add "KeyPress", "TheMP Focus", (ply, key) ->
    tr = ply\GetEyeTrace!

    if key == IN_USE
        if not ply\GetNW2Bool "TheMP Focused"
            timer.Simple 0, () ->
                if tr and IsValid(tr.Entity) and tr.Entity.ApplyDeltas and not tr.Entity\IsPlayerHolding!
                    Moonpanel\setFocused ply, true
        else
            Moonpanel\setFocused ply, false
    if key == IN_ATTACK and (Moonpanel\isFocused ply) 
        Moonpanel\requestControl ply, ply\GetNW2Entity("TheMP Controlled Panel"), x, y

hook.Add "Think", "TheMP Think", () ->
    for k, v in pairs player.GetAll!
        panel = v\GetNW2Entity("TheMP Controlled Panel")

        if not IsValid panel
            v\SetNW2Entity("TheMP Controlled Panel", nil)

        if IsValid(panel) and panel\GetNW2Entity("ActiveUser") ~= v
            v\SetNW2Entity("TheMP Controlled Panel", nil)

        if v\GetNW2Bool "TheMP Focused"
            v\SelectWeapon "none"

hook.Add "PostPlayerDeath", "TheMP PlayerDeath", (ply) ->
    Moonpanel\setFocused ply, false, true

hook.Add "PlayerSilentDeath", "TheMP PlayerDeath", (ply) ->
    Moonpanel\setFocused ply, false, true