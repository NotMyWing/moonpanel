-- Optional WireMod Expression 2 extension. WireMod automatically loads files
-- in this directory; the extension is inert when WireMod/E2 is not installed.

if not E2Lib then return end

E2Lib.RegisterExtension("moonpanel", false,
    "Read and control Moonpanel entities through owner-checked helpers.")

__e2setcost(2)

local function panelEntity(entity)
    if not IsValid(entity) or not entity.Moonpanel then return nil end
    return entity
end

local function canvasData(entity)
    local panel = panelEntity(entity)
    return panel and panel:GetCanvas():GetData() or nil
end

e2function number entity:moonpanelPowered()
    local panel = panelEntity(this)
    return panel and panel:GetPowered() and 1 or 0
end

e2function number entity:moonpanelSolved()
    local panel = panelEntity(this)
    return panel and panel:GetSolvedState() and 1 or 0
end

e2function number entity:moonpanelErrored()
    local panel = panelEntity(this)
    return panel and panel:GetErrored() and 1 or 0
end

e2function string entity:moonpanelPath()
    local panel = panelEntity(this)
    local state = panel and panel:GetWireState()
    return state and state.path or ""
end

e2function number entity:moonpanelRevision()
    local panel = panelEntity(this)
    return panel and panel:GetPanelRevision() or 0
end

e2function number entity:moonpanelWidth()
    local data = canvasData(this)
    return data and data.Meta and (tonumber(data.Meta.Width) or 0) or 0
end

e2function number entity:moonpanelHeight()
    local data = canvasData(this)
    return data and data.Meta and (tonumber(data.Meta.Height) or 0) or 0
end

__e2setcost(5)

e2function number entity:moonpanelReset()
    local panel = panelEntity(this)
    if not panel or not isOwner(self, panel) then
        return 0
    end
    return panel:ResetPanel() and 1 or 0
end
