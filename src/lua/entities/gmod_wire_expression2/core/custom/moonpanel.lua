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

local function panelDimensions(entity)
    local panel = panelEntity(entity)
    if not panel then return 0, 0 end
    return panel:GetCanvas():GetDimensions()
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
    local width = panelDimensions(this)
    return tonumber(width) or 0
end

e2function number entity:moonpanelHeight()
    local _, height = panelDimensions(this)
    return tonumber(height) or 0
end

__e2setcost(5)

e2function number entity:moonpanelReset()
    local panel = panelEntity(this)
    if not panel or not isOwner(self, panel) then
        return 0
    end
    return panel:ResetPanel() and 1 or 0
end
