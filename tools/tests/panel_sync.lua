local test = dofile('tools/tests/harness.lua')

include = function() end
table.Copy = table.Copy or function(value)
  local output = {}
  for key, child in pairs(value or {}) do output[key] = child end
  return output
end

local sent = {}
Moonpanel.Net = {
  SendPanelData = function(ply, panel, data)
    table.insert(sent, { ply = ply, panel = panel, revision = data.revision })
    return true
  end,
  SendControlGrant = function() end,
  PanelRequestDataFromPlayer = function() return true end,
}
Moonpanel.Canvas.SanitizeData = function(data)
  return type(data) == 'table' and table.Copy(data) or nil
end
Moonpanel.IsFocused = function() return true end
Moonpanel.SetFocused = function(_, ply, focused)
  ply.focused = focused == true
end

IsValid = function(value) return type(value) == 'table' and value.valid ~= false end
game = {
  GetWorld = function()
    return { world = true, IsPlayer = function() return false end }
  end,
}
ENT = {}
dofile('dest/lua/entities/moonpanel/init.lua')

local function player()
  return {
    IsPlayer = function() return true end,
  }
end

local function panel()
  return setmetatable({
    __syncedPlayers = {},
    __pendingSyncs = {},
    syncData = nil,
    BuildPanelSyncData = function(self) return self.syncData end,
  }, { __index = ENT })
end

test.test('subsequent panel data assignments resync known players', function()
  local panelEntity = panel()
  local ply = player()

  panelEntity:SyncPlayer(ply)
  assert(panelEntity.__pendingSyncs[ply], 'data-less panel did not queue its player')
  assert(#sent == 0, 'data-less panel sent an invalid snapshot')

  panelEntity.syncData = { revision = 1 }
  panelEntity:ExecutePendingSyncs()
  assert(#sent == 1 and sent[1].revision == 1,
    'first panel assignment did not sync the pending player')
  assert(panelEntity.__syncedPlayers[ply],
    'successful sync did not remember the player')

  panelEntity.syncData = { revision = 2 }
  panelEntity:ExecutePendingSyncs()
  assert(#sent == 2 and sent[2].revision == 2,
    'replacement panel data was not sent to the known player')
end)

test.test('panel SetData ingests and stores each replacement', function()
  local panelEntity = panel()
  local canvas = {
    imports = 0,
    data = nil,
    CancelSolution = function() end,
    ImportData = function(self, data)
      self.imports = self.imports + 1
      self.data = table.Copy(data)
    end,
    ExportData = function(self) return table.Copy(self.data) end,
  }
  panelEntity.GetCanvas = function() return canvas end
  panelEntity.SetSolvedState = function(self, solved) self.solved = solved == true end
  panelEntity.SetPowered = function(self, powered) self.powered = powered == true end

  assert(panelEntity:SetData({ revision = 1 }), 'first SetData was rejected')
  assert(panelEntity:SetData({ revision = 2 }), 'replacement SetData was rejected')
  assert(canvas.imports == 2 and canvas.data.revision == 2,
    'replacement was not imported into the panel canvas')
  assert(panelEntity.TheMoonpanelTileData.revision == 2,
    'panel did not store the rebuilt canonical replacement')
  assert(panelEntity.powered and not panelEntity.solved,
    'replacement did not restore the expected panel state')
  assert(panelEntity.__dataRevision == 2,
    'panel data generation did not advance for each replacement')
end)

test.test('panel SetData evicts an active controller before import', function()
  local panelEntity = panel()
  local controller = player()
  controller.focused = true
  local importedWhileActive = false
  local canvas = {
    CancelSolution = function() end,
    ImportData = function(self, data)
      importedWhileActive = panelEntity.__traceSession ~= nil
      self.data = table.Copy(data)
    end,
    ExportData = function(self) return table.Copy(self.data) end,
  }
  panelEntity.GetCanvas = function() return canvas end
  panelEntity.GetController = function(self) return self.controller end
  panelEntity.SetController = function(self, value) self.controller = value end
  panelEntity.SetSolvedState = function() end
  panelEntity.SetPowered = function() end
  panelEntity.controller = controller
  panelEntity.__traceSession = { controller = controller }
  panelEntity.EndTraceSession = function(self)
    self.__traceSession = nil
    self.controller = game.GetWorld()
    return true
  end

  assert(panelEntity:SetData({ revision = 1 }), 'SetData rejected a valid edit')
  assert(not importedWhileActive, 'panel imported replacement before ending its trace')
  assert(controller.focused == false, 'active controller remained focused after panel edit')
  assert(panelEntity.controller.world == true, 'panel retained its active controller')
end)

test.run()
