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
    if not panel or not panel.GetCanvas then return nil end
    local canvas = panel:GetCanvas()
    return canvas and canvas:GetData() or nil
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
    local state = panel and panel.GetWireState and panel:GetWireState()
    return state and state.path or ""
end

e2function number entity:moonpanelRevision()
    local panel = panelEntity(this)
    return panel and panel.GetPanelRevision and panel:GetPanelRevision() or 0
end

e2function number entity:moonpanelWidth()
    local data = canvasData(this)
    return data and data.Meta and (tonumber(data.Meta.Width) or 0) or 0
end

e2function number entity:moonpanelHeight()
    local data = canvasData(this)
    return data and data.Meta and (tonumber(data.Meta.Height) or 0) or 0
end

-- Read one authored cell without exposing the entire mutable canvas.
e2function string entity:moonpanelCell(number x, number y)
    local panel = panelEntity(this)
    local canvas = panel and panel:GetCanvas()
    if not canvas or not canvas.GetCellSocketAt then return "" end
    local socket = canvas:GetCellSocketAt(math.floor(x), math.floor(y))
    local entity = socket and socket:GetEntity()
    local data = entity and entity:ExportData()
    return data and data.Type or ""
end

__e2setcost(10)

e2function string entity:moonpanelData()
    local data = canvasData(this)
    if not data then return "" end
    -- Keep E2 string traffic bounded; callers needing individual values can
    -- use the typed helpers above.
    return string.sub(util.TableToJSON(data, false) or "", 1, 8192)
end

__e2setcost(5)

e2function number entity:moonpanelReset()
    local panel = panelEntity(this)
    if not panel or not panel.ResetPanel or not isOwner(self, panel) then
        return 0
    end
    return panel:ResetPanel() and 1 or 0
end
