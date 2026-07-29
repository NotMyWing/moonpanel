local test = dofile('tools/tests/harness.lua')

include = function() end
istable = function(value) return type(value) == 'table' end
local delayedTimer
timer = {
  Remove = function() end,
  Create = function(_, _, _, callback) delayedTimer = callback end,
}
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
Moonpanel.Wire = { UpdateState = function() end }
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
dofile('dest/lua/moonpanel/sh_trace_session.lua')
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
    GetController = function(self) return self.controller or game.GetWorld() end,
    SetController = function(self, controller) self.controller = controller end,
    SetErrored = function(self, value) self.errored = value == true end,
    EntIndex = function() return 1 end,
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
      importedWhileActive = Moonpanel.TraceSession.Get(panelEntity) ~= nil
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
  Moonpanel.TraceSession.Set(panelEntity, { controller = controller })
  panelEntity.EndTraceSession = function(self)
    Moonpanel.TraceSession.Set(self, nil)
    self.controller = game.GetWorld()
    return true
  end

  assert(panelEntity:SetData({ revision = 1 }), 'SetData rejected a valid edit')
  assert(not importedWhileActive, 'panel imported replacement before ending its trace')
  assert(controller.focused == false, 'active controller remained focused after panel edit')
  assert(panelEntity.controller.world == true, 'panel retained its active controller')
end)

test.test('terminal eraser delay latches errored after feedback', function()
  local panelEntity = panel()
  panelEntity.SetSolvedState = function(self, solved) self.solved = solved == true end
  panelEntity.SetErrored = function(self, errored) self.errored = errored == true end
  panelEntity.ExecutePendingSyncs = function() end
  panelEntity.GetCanvas = function()
    return { CancelSolution = function() end }
  end
  local result = {
    success = false,
    aborted = false,
    feedback = { erasures = { { targetIndex = 1 } } },
  }

  SERVER = true
  assert(panelEntity:ApplyTerminalResult(result), 'terminal result was rejected')
  SERVER = nil
  assert(not panelEntity.solved and not panelEntity.errored,
    'errored became visible before eraser feedback finished')
  assert(delayedTimer, 'eraser feedback did not schedule the terminal transition')
  delayedTimer()
  assert(not panelEntity.solved and panelEntity.errored,
    'failed terminal result did not latch errored after the delay')
end)

test.test('Wire terminal result derives one path update from lifecycle state', function()
  local outputs = {}
  WireLib = {
    TriggerOutput = function(_, name, value)
      outputs[#outputs + 1] = { name = name, value = value }
    end,
  }
  dofile('dest/lua/moonpanel/sv_wire.lua')
  local panelEntity = panel()
  panelEntity.WireOutputs = {}
  panelEntity.powered, panelEntity.solved, panelEntity.errored = true, false, true
  panelEntity.GetPowered = function(self) return self.powered end
  panelEntity.GetSolvedState = function(self) return self.solved end
  panelEntity.GetErrored = function(self) return self.errored end
  panelEntity.GetCanvas = function()
    return {
      GetTracePath = function() return 'R R U' end,
      GetSocketAtDataIndex = function() return nil end,
    }
  end

  SERVER = true
  Moonpanel.Wire.HandleResult(panelEntity, {
    success = false, feedback = { erasures = {} }, snapshot = {},
  })
  SERVER = nil
  local paths = 0
  for _, output in ipairs(outputs) do
    if output.name == 'Path' then
      paths = paths + 1
      assert(output.value == 'R R U', 'Wire path did not use terminal trace state')
    end
  end
  assert(paths == 1, 'Wire terminal handling assigned Path more than once')
end)

test.run()
