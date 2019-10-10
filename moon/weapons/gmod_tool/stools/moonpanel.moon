TOOL.Category		= "Neeve's Addons"
TOOL.Name			= "The Witness - The Moonpanel"
TOOL.Command		= nil
TOOL.ConfigName		= ""

-- ------------------------------- Sending / Receiving ------------------------------- --

TOOL.ClientConVar["Model"] = "models/hunter/plates/plate2x2.mdl"
TOOL.ClientConVar["Type"] = 1
TOOL.Reload = () =>
TOOL.DrawHUD = () =>

cleanup.Register("moonpanels")

if SERVER
    CreateConVar "sbox_maxmoonpanels", 3, { FCVAR_REPLICATED, FCVAR_NOTIFY, FCVAR_ARCHIVE }

    createMoonpanel = (pl, pos, ang, model, tileData) ->
        if not (pl\CheckLimit "moonpanels")
            return false

        sf = ents.Create "moonpanel"
        if not IsValid(sf)
            return false

        with sf
            \SetAngles ang
            \SetPos pos
            \SetModel model
            \Spawn!

        if tileData
            sf\SetupData tileData

        pl\AddCount "moonpanels", sf
        pl\AddCleanup "moonpanels", sf

        return sf

    duplicator.RegisterEntityClass("moonpanel", createMoonpanel, "Pos", "Ang", "Model", "TheMoonpanelTileData")

    TOOL.LeftClick = (trace) =>
        if not trace.HitPos
            return false
        if trace.Entity\IsPlayer! or trace.Entity\IsNPC!
            return false

        ply = @GetOwner!

        panel = (() -> 
            if trace.Entity\IsValid! and trace.Entity.Moonpanel
                if not trace.Entity\Desync!
                    return Moonpanel\sendNotify ply, "Please wait before sending an update again!", "buttons/button10.wav", NOTIFY_ERROR
                else
                    return trace.Entity

            else   
                Ang = trace.HitNormal\Angle!
                Ang.pitch = Ang.pitch + 90
                model = @GetClientInfo "Model"
                if not ((util.IsValidModel model) and (util.IsValidProp model))
                    print "? 2", (util.IsValidModel model), (util.IsValidProp model)
                    return nil

                sf = createMoonpanel ply, Vector(), Ang, model
                if not sf
                    print "? 3"
                    return nil

                min = sf\OBBMins!
                sf\SetPos trace.HitPos - trace.HitNormal * min.z

                const = nil
                phys = sf\GetPhysicsObject()
                if trace.Entity\IsValid!
                    const = constraint.Weld sf, trace.Entity, 0, trace.PhysicsBone, 0, true, true
                    if phys\IsValid! 
                        phys\EnableCollisions(false) 
                        sf.nocollide = true
                else
                    if phys\IsValid()
                        phys\EnableMotion(false)

                undo.Create("moonpanel")
                undo.AddEntity(sf)
                if const
                    undo.AddEntity(const)
                undo.SetPlayer(ply)
                undo.Finish()

                return sf
        )!

        if not IsValid panel
            return false

        success = (data) ->
            if IsValid panel
                panel\SetupData data

        Moonpanel\requestEditorConfig @GetOwner!, success

        return true

    TOOL.RightClick = (trace) =>
        net.Start "TheMP Editor"
        net.Send @GetOwner!

else
    language.Add "Tool.moonpanel.name", "The Moonpanel"
    language.Add "Tool.moonpanel.desc", "Spawns a Moonpanel."
    language.Add "sboxlimit_moonpanels", "You've hit the Moonpanel limit!"
    language.Add "undone_moonpanel", "Undone Moonpanel"
    language.Add "Cleanup_moonpanel", "Moonpanels"
    TOOL.Information = {
        { name: "left", stage: 0, text: "Spawn/update a Moonpanel" },
        { name: "right_0", stage: 0, text: "Open the editor" },
    }

    for _, info in pairs(TOOL.Information)
        language.Add("Tool.moonpanel." .. info.name, info.text)

    TOOL.BuildCPanel = (panel) ->
        panel\AddControl("Header", { Text: "#Tool.moonpanel.name", Description: "#Tool.moonpanel.desc" })

        modelPanel = vgui.Create("DPanelSelect", panel)
        modelPanel\EnableVerticalScrollbar()
        modelPanel\SetTall(66 * 5 + 2)
        t = (scripted_ents.GetStored("moonpanel").t.Monitor_Offsets) or {}
        for model, v in pairs(t)
            icon = vgui.Create("SpawnIcon")
            icon\SetModel(model)
            icon.Model = model
            icon\SetSize(64, 64)
            icon\SetTooltip(model)
            modelPanel\AddPanel(icon, { ["moonpanel_Model"]: model })

        modelPanel\SortByMember("Model", false)
        panel\AddPanel(modelPanel)

        panel\AddControl("Label", { Text: "" })

    TOOL.LeftClick = () => true

TOOL.Think = () =>
    model = @GetClientInfo("Model")

    if (not IsValid(self.GhostEntity) or self.GhostEntity\GetModel! ~= model) then
        @MakeGhostEntity model, Vector(0, 0, 0), Angle(0, 0, 0)

    trace = util.TraceLine(util.GetPlayerTrace(self\GetOwner!))
    if (not trace.Hit)
        return

    ent = self.GhostEntity

    if not IsValid(ent)
        return

    Ang = trace.HitNormal\Angle!
    Ang.pitch = Ang.pitch + 90

    min = ent\OBBMins!
    ent\SetPos trace.HitPos - trace.HitNormal * min.z
    ent\SetAngles Ang