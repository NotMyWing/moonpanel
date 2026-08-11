local test = dofile('tools/tests/harness.lua')

dofile('dest/lua/moonpanel/canvas/cl_rtpool.lua')

local function reset(limit)
  _G.TEST_CONVAR_INTS.moonpanel_rt_pool_max_pages = limit
  _G.TEST_RT_CREATED = 0
  _G.TEST_CREATED_MATERIALS = {}
  Moonpanel.Canvas.__allocatedRTs = nil
  Moonpanel.Canvas.__freeRTs = nil
  Moonpanel.Canvas.__rtTokens = nil
  Moonpanel.Canvas.__rtPageCount = nil
  Moonpanel.Canvas.__auxiliaryRT = nil
  Moonpanel.Canvas:BakePages()
end

test.test('main page exposes unlit and shader-composited views of one RT', function()
  reset(1)
  local rt = assert(Moonpanel.Canvas:AllocateRT()).rt
  assert(_G.TEST_RT_CREATED == 1, 'world material allocated another texture')
  assert(#_G.TEST_CREATED_MATERIALS == 2,
    'main page did not create its compositor and VGUI material views')
  assert(rt.material.shader == 'UnlitGeneric' and
    rt.displayMaterial.shader == 'screenspace_general',
    'world and VGUI material roles use the wrong Source shaders')
  assert(rt.material.parameters['$basetexture'] == rt.texture:GetName() and
    rt.displayMaterial.parameters['$basetexture'] == rt.texture:GetName() and
    rt.displayMaterial.parameters['$pixshader'] == 'moonpanel_display_v3_ps20' and
    rt.displayMaterial.parameters['$vertexshader'] == 'moonpanel_display_v3_vs20' and
    rt.displayMaterial.parameters['$vertextransform'] == nil,
    'world compositor is not sampling the authored panel texture')
end)

test.test('render-target pages are lazy and grow geometrically', function()
  reset(16)
  assert(_G.TEST_RT_CREATED == 0, 'pool initialization allocated render targets')

  local allocations = {}
  local expectedCreated = {1, 2, 4, 4, 8, 8, 8, 8, 16}
  for index = 1, #expectedCreated do
    allocations[index] = Moonpanel.Canvas:AllocateRT()
    assert(allocations[index], 'pool ran out before reaching its limit')
    assert(_G.TEST_RT_CREATED == expectedCreated[index], 'pool did not double its page target')
  end

  for _, allocation in ipairs(allocations) do
    Moonpanel.Canvas:DeallocateRT(allocation)
  end
  local reused = Moonpanel.Canvas:AllocateRT()
  assert(reused, 'deallocated target was not reusable')
  assert(_G.TEST_RT_CREATED == 16, 'reuse allocated a new render target')
end)

test.test('non-power-of-two limits are exact final growth targets', function()
  for _, limit in ipairs({7, 10, 13}) do
    reset(limit)
    local allocations = {}
    for index = 1, limit do
      allocations[index] = Moonpanel.Canvas:AllocateRT()
      assert(allocations[index], 'allocation stopped below configured limit')
    end
    assert(_G.TEST_RT_CREATED == limit, 'configured limit was rounded to a power of two')
    assert(not Moonpanel.Canvas:AllocateRT(), 'allocation exceeded configured limit')
  end
end)

test.test('auxiliary target is independent and lazy', function()
  reset(16)
  assert(_G.TEST_RT_CREATED == 0, 'page baking crossed into auxiliary allocation')
  local auxiliary = Moonpanel.Canvas:BakeAuxiliaryRT()
  assert(auxiliary and _G.TEST_RT_CREATED == 1, 'auxiliary target was not baked separately')
  assert(auxiliary.worldMaterial == nil, 'auxiliary target gained a world material')
  assert(Moonpanel.Canvas:GetAuxiliaryRT() == auxiliary)
  local page = Moonpanel.Canvas:AllocateRT()
  assert(page and _G.TEST_RT_CREATED == 2, 'auxiliary target consumed a pool page')
end)

test.test('world renderer uses the identity compositor with exact fallback', function()
  reset(1)
  local rt = assert(Moonpanel.Canvas:AllocateRT()).rt
  _G.TEST_RENDER_STATE = {
    material = nil,
    blend = 0.6,
    modulation = {0.2, 0.3, 0.4},
    flashlights = true,
  }
  local draws = {}
  local mesh = {Draw = function()
    local state = _G.TEST_RENDER_STATE
    draws[#draws + 1] = {
      material = state.material,
      blend = state.blend,
      modulation = {state.modulation[1], state.modulation[2], state.modulation[3]},
    }
  end}

  _G.TEST_CONVAR_INTS[Moonpanel.CVarNames.ScreenWorldLighting] = 1
  Moonpanel.Canvas.DrawWorldRT(rt, mesh, 0.5)
  assert(#draws == 1 and draws[1].material == rt.displayMaterial,
    'world renderer did not use the identity compositor')
  assert(draws[1].blend == 1 and draws[1].modulation[1] == 1 and
    rt.displayMaterial.parameters['$c0_x'] == 0.5,
    'panel power did not reach the compositor')
  local restored = _G.TEST_RENDER_STATE
  assert(restored.blend == 0.6 and restored.modulation[1] == 0.2 and
    restored.modulation[2] == 0.3 and restored.modulation[3] == 0.4,
    'world renderer leaked blend or color modulation state')

  draws = {}
  Moonpanel.Canvas.DrawWorldRT(rt, mesh, 0)
  assert(#draws == 1 and draws[1].material == rt.displayMaterial and
    rt.displayMaterial.parameters['$c0_x'] == 0,
    'unpowered panel retained visible display emission')

  draws = {}
  _G.TEST_CONVAR_INTS[Moonpanel.CVarNames.ScreenWorldLighting] = 0
  Moonpanel.Canvas.DrawWorldRT(rt, mesh, 0.75)
  assert(#draws == 1 and draws[1].material == rt.material and
    draws[1].blend == 1,
    'disabled world lighting did not restore the exact unlit pass')
end)

test.test('world compositor restores render state after draw errors', function()
  reset(1)
  local rt = assert(Moonpanel.Canvas:AllocateRT()).rt
  _G.TEST_RENDER_STATE = {
    material = nil,
    blend = 0.4,
    modulation = {0.1, 0.2, 0.3},
  }
  _G.TEST_CONVAR_INTS[Moonpanel.CVarNames.ScreenWorldLighting] = 1

  local ok = pcall(Moonpanel.Canvas.DrawWorldRT, rt,
    {Draw = function() error('intentional render failure') end}, 1)
  assert(not ok, 'world compositor swallowed a draw failure')
  local restored = _G.TEST_RENDER_STATE
  assert(restored.blend == 0.4 and restored.modulation[1] == 0.1 and
    restored.modulation[2] == 0.2 and restored.modulation[3] == 0.3,
    'failed world draw leaked blend or color modulation state')
end)

test.test('forced allocation evicts the oldest active target', function()
  reset(1)
  local first = Moonpanel.Canvas:AllocateRT()
  local second = Moonpanel.Canvas:AllocateRT(true)
  assert(second, 'forced allocation did not reclaim the capped pool')
  assert(not Moonpanel.Canvas:IsRTAllocated(first), 'oldest target remained allocated')
  assert(_G.TEST_RT_CREATED == 1, 'forced eviction created an extra render target')
end)

test.run()
