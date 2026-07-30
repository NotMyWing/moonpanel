_G.resource = {AddFile = function() end}
_G.util = {TraceLine = function() return {Hit = false, Fraction = 1} end}
_G.Material = function(path) return {path = path} end
_G.Sound = function(path) return path end
_G.math.Round = math.Round or function(value)
  return value >= 0 and math.floor(value + 0.5) or math.ceil(value - 0.5)
end
local vectorMeta = {}
vectorMeta.__index = vectorMeta
vectorMeta.__add = function(a, b) return Vector(a.x + b.x, a.y + b.y, a.z + b.z) end
vectorMeta.__sub = function(a, b) return Vector(a.x - b.x, a.y - b.y, a.z - b.z) end
vectorMeta.__mul = function(a, b)
  if type(a) == 'number' then return Vector(a * b.x, a * b.y, a * b.z) end
  if type(b) == 'number' then return Vector(a.x * b, a.y * b, a.z * b) end
  return Vector(a.x * b.x, a.y * b.y, a.z * b.z)
end
vectorMeta.__div = function(a, b) return Vector(a.x / b, a.y / b, a.z / b) end
vectorMeta.Length = function(value)
  return math.sqrt(value.x * value.x + value.y * value.y + value.z * value.z)
end
_G.Vector = function(x, y, z)
  if type(x) == 'table' then return setmetatable({x = x.x, y = x.y, z = x.z}, vectorMeta) end
  return setmetatable({x = x or 0, y = y or 0, z = z or 0}, vectorMeta)
end
_G.Angle = function(p, y, r) return {p = p or 0, y = y or 0, r = r or 0} end
_G.Matrix = function()
  return setmetatable({SetAngles = function() end, SetTranslation = function() end,
    SetScale = function() end}, {__mul = function() return Matrix() end})
end

_G.Moonpanel.Rect = function(x, y, width, height)
  return {x = x, y = y, width = width, height = height}
end
local canvasRoot = 'dest/lua/moonpanel/canvas/'
_G.include = function(path) return dofile(canvasRoot .. path) end
dofile('dest/lua/moonpanel/sh_colors.lua')
dofile(canvasRoot .. 'sh_helpers.lua')
dofile(canvasRoot .. 'sh_canvas.lua')

local fixtures = dofile('dest/test/panel_fixtures.lua')
local function panel(name)
  for _, entry in ipairs(fixtures) do
    if entry.name == name then return entry.panel end
  end
  error('missing generated panel fixture: ' .. name)
end
return panel
