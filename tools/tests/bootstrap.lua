_G.TEST_NOW = 0
_G.TEST_FRAME_TIME = 1 / 60
_G.TEST_WORLD = {world = true, IsPlayer = function() return false end}
_G.CurTime = function() return _G.TEST_NOW end
_G.RealTime = _G.CurTime
_G.FrameTime = function() return _G.TEST_FRAME_TIME end
math.Clamp = math.Clamp or function(value, minimum, maximum)
  return math.max(minimum, math.min(maximum, value))
end
_G.bit = _G.bit or {
  bxor = assert(load('return function(a, b) return (a ~ b) & 0xffffffff end'))(),
}
_G.Moonpanel = {
  Canvas = {
    Symmetry = {None = 0, Vertical = 1, Horizontal = 2, Rotational = 3},
    SocketType = {Intersection = 1, Cell = 2, Path = 3},
  },
}
-- Keep runtime tests on the same CVar registry as the addon modules they load.
dofile('dest/lua/moonpanel/sh_cvars.lua')

_G.AddCSLuaFile = _G.AddCSLuaFile or function() end
_G.CLIENT = _G.CLIENT or false
_G.SERVER = _G.SERVER or false
_G.include = _G.include or function() end
_G.isnumber = _G.isnumber or function(value) return type(value) == 'number' end
_G.isstring = _G.isstring or function(value) return type(value) == 'string' end
_G.istable = _G.istable or function(value) return type(value) == 'table' end
_G.isfunction = _G.isfunction or function(value) return type(value) == 'function' end
_G.IsValid = _G.IsValid or function(value)
  return type(value) == 'table' and value ~= _G.TEST_WORLD and value.valid ~= false
end
_G.Color = _G.Color or function(r, g, b, a) return {r = r, g = g, b = b, a = a or 255} end
_G.Vector = _G.Vector or function(x, y, z) return {x = x, y = y, z = z} end
_G.draw = _G.draw or {RoundedBox = function() end, SimpleText = function() end}
_G.render = _G.render or {DrawLine = function() end}
_G.hook = _G.hook or {Add = function() end, Remove = function() end}
_G.cvars = _G.cvars or {AddChangeCallback = function() end}
_G.concommand = _G.concommand or {Add = function() end}
_G.timer = _G.timer or {Simple = function() end}
_G.ents = _G.ents or {FindByClass = function() return {} end}
_G.cam = _G.cam or {Start3D2D = function() end, End3D2D = function() end}
_G.TEXT_ALIGN_LEFT = _G.TEXT_ALIGN_LEFT or 0
_G.TEXT_ALIGN_TOP = _G.TEXT_ALIGN_TOP or 0
_G.EyePos = _G.EyePos or function()
  return {DistToSqr = function() return 0 end}
end
_G.TEST_CONVAR_INTS = _G.TEST_CONVAR_INTS or {}
local function testConVar(name)
  return {
    GetBool = function() return false end,
    GetFloat = function() return 4096 end,
    GetInt = function() return _G.TEST_CONVAR_INTS[name] or 1 end,
  }
end
_G.CreateClientConVar = _G.CreateClientConVar or function(name) return testConVar(name) end
_G.GetConVar = _G.GetConVar or function(name) return testConVar(name) end
_G.RunConsoleCommand = _G.RunConsoleCommand or function() end
_G.MsgC = _G.MsgC or function() end
_G.surface = _G.surface or {
  CreateFont = function() end, SetFont = function() end,
  GetTextSize = function(text) return #text * 8, 18 end,
  SetDrawColor = function() end, DrawRect = function() end,
}
_G.TEST_DELAYED_TIMER = nil
_G.TEST_TIMER = {callbacks = {}, pending = 0, peak = 0, assertZero = false}
_G.TEST_SENT = {}
_G.timer = _G.timer or {}
_G.timer.Remove = _G.timer.Remove or function() end
_G.timer.Create = _G.timer.Create or function(_, _, _, callback)
  _G.TEST_DELAYED_TIMER = callback
end
_G.timer.Simple = function(delay, callback)
  local state = _G.TEST_TIMER
  assert(not state.assertZero or delay == 0, 'test timer used a non-zero delay')
  state.pending = state.pending + 1
  state.peak = math.max(state.peak, state.pending)
  state.callbacks[#state.callbacks + 1] = callback
end
_G.Moonpanel.Net = _G.Moonpanel.Net or {
  SendPanelData = function(ply, panel, data)
    _G.TEST_SENT[#_G.TEST_SENT + 1] = {ply = ply, panel = panel, revision = data.revision}
    return true
  end,
  SendControlGrant = function() end,
  PanelRequestDataFromPlayer = function() return true end,
}
_G.Moonpanel.Net.TraceSessions = _G.Moonpanel.Net.TraceSessions or {}
_G.Moonpanel.Net.PendingPanelDataRequests = _G.Moonpanel.Net.PendingPanelDataRequests or {}
_G.Moonpanel.Wire = _G.Moonpanel.Wire or {UpdateState = function() end}
_G.Moonpanel.Canvas.SanitizeData = _G.Moonpanel.Canvas.SanitizeData or function(data)
  return type(data) == 'table' and table.Copy(data) or nil
end
_G.Moonpanel.IsFocused = _G.Moonpanel.IsFocused or function() return true end
_G.Moonpanel.SetFocused = _G.Moonpanel.SetFocused or function(_, ply, focused)
  ply.focused = focused == true
end
_G.game = _G.game or {GetWorld = function() return _G.TEST_WORLD end}
_G.ENT = _G.ENT or {}
local testPlayerPosition = {Distance = function() return 128 end}
local testLocalPlayer = {EyePos = function() return testPlayerPosition end}
_G.LocalPlayer = _G.LocalPlayer or function() return testLocalPlayer end
_G.util = _G.util or {}
local stackMethods = {}
function stackMethods:Push(value)
  self[#self + 1] = value
end
function stackMethods:Pop()
  local value = self[#self]
  self[#self] = nil
  return value
end
function stackMethods:Size()
  return #self
end
_G.util.Stack = _G.util.Stack or function()
  return setmetatable({}, {__index = stackMethods})
end
_G.TEST_RT_CREATED = _G.TEST_RT_CREATED or 0
_G.GetRenderTargetEx = _G.GetRenderTargetEx or function(name)
  _G.TEST_RT_CREATED = _G.TEST_RT_CREATED + 1
  return {GetName = function() return name end}
end
_G.CreateMaterial = _G.CreateMaterial or function() return {} end
_G.RT_SIZE_OFFSCREEN = _G.RT_SIZE_OFFSCREEN or 1
_G.MATERIAL_RT_DEPTH_SHARED = _G.MATERIAL_RT_DEPTH_SHARED or 2
_G.CREATERENDERTARGETFLAGS_HDR = _G.CREATERENDERTARGETFLAGS_HDR or 4
_G.IMAGE_FORMAT_RGBA8888 = _G.IMAGE_FORMAT_RGBA8888 or 5
_G.TEST_PROXY_ID = _G.TEST_PROXY_ID or 0
_G.newproxy = _G.newproxy or function()
  _G.TEST_PROXY_ID = _G.TEST_PROXY_ID + 1
  return setmetatable({id = _G.TEST_PROXY_ID}, {})
end
_G.Moonpanel.Canvas.IsRTAllocated = _G.Moonpanel.Canvas.IsRTAllocated or function() return true end
_G.TestTraceLine = function(handler)
  local trace = {}
  function trace:set(nextHandler) self.handler = nextHandler end
  setmetatable(trace, {__call = function(self, request)
    return (self.handler or handler or function() return {Hit = false, Fraction = 1} end)(request)
  end})
  return trace
end
_G.TEST_FILE_STATE = {}
_G.util.JSONToTable = function(contents)
  return contents == 'metadata' and _G.TEST_FILE_STATE.metadata or nil
end
_G.util.TableToJSON = function() return '{}' end
_G.file = {
  Exists = function(path, realm)
    assert(realm == 'DATA')
    local state = _G.TEST_FILE_STATE
    if path == 'moonpanel/autosave.meta.txt' then return state.metadata ~= nil end
    if path == 'moonpanel/autosave.txt' then return state.exists == true end
    return state.metadata and path == state.metadata.path and state.openedData ~= nil
  end,
  Read = function(path, realm)
    assert(realm == 'DATA')
    local state = _G.TEST_FILE_STATE
    if path == 'moonpanel/autosave.meta.txt' then return state.metadata and 'metadata' or nil end
    if path == 'moonpanel/autosave.txt' then
      return state.exists and (state.serializedData and 'valid' or 'corrupt') or nil
    end
    return state.metadata and path == state.metadata.path and state.openedData and 'opened' or nil
  end,
}

table.Count = table.Count or function(value)
  local count = 0
  for _ in pairs(value or {}) do count = count + 1 end
  return count
end

table.Copy = table.Copy or function(value, seen)
  if type(value) ~= 'table' then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local output = {}
  seen[value] = output
  for key, child in pairs(value) do
    output[table.Copy(key, seen)] = table.Copy(child, seen)
  end
  return output
end

_G.util = _G.util or {
  JSONToTable = function() return nil end,
  TableToJSON = function() return '' end,
}
