local test = dofile('tools/tests/harness.lua')

dofile('dest/lua/moonpanel/canvas/cl_rtpool.lua')

local function reset(limit)
  _G.TEST_CONVAR_INTS.moonpanel_rt_pool_max_pages = limit
  _G.TEST_RT_CREATED = 0
  Moonpanel.Canvas.__allocatedRTs = nil
  Moonpanel.Canvas.__freeRTs = nil
  Moonpanel.Canvas.__rtTokens = nil
  Moonpanel.Canvas.__rtPageCount = nil
  Moonpanel.Canvas.__auxiliaryRT = nil
  Moonpanel.Canvas:BakePages()
end

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
  assert(Moonpanel.Canvas:GetAuxiliaryRT() == auxiliary)
  local page = Moonpanel.Canvas:AllocateRT()
  assert(page and _G.TEST_RT_CREATED == 2, 'auxiliary target consumed a pool page')
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
