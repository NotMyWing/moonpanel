ENT.Type            = "anim"
ENT.Base            = "base_gmodentity"

ENT.PrintName       = "The Moonpanel"
ENT.Author          = "Notmywing"
ENT.Contact         = "winwyv@gmail.com"
ENT.Purpose         = ""
ENT.Instructions    = ""

ENT.Spawnable       = false

ENT.TickRate        = 20

ENT.ApplyDeltas = (x, y) =>
	print x, y

ENT.Think = () =>
    if SERVER
        @ServerThink!
    else
        @ClientThink!

    if CurTime! >= (@__nextTRThink or 0)
        @__nextTRThink = CurTime! + (1 / @TickRate)

        if SERVER
            @ServerTickrateThink!
        else
            @ClientTickrateThink!