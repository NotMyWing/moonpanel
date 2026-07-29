local test = dofile('tools/tests/harness.lua')
dofile('dest/lua/moonpanel/canvas/sh_pathfinder.lua')
dofile('dest/lua/moonpanel/canvas/cl_presentation.lua')

local function lineTopology(symmetry)
  local left = { x = -1, y = 0, screenX = 0, screenY = 0, neighbors = {} }
  local center = { x = 0, y = 0, screenX = 100, screenY = 0, clickable = true, neighbors = {} }
  local right = { x = 1, y = 0, screenX = 200, screenY = 0, neighbors = {} }
  left.neighbors = { center }
  center.neighbors = { left, right }
  right.neighbors = { center }
  return Moonpanel.Canvas.TraceTopology({
    nodes = { left, center, right }, barWidth = 10, barLength = 100,
    symmetry = symmetry or 0,
  })
end

local function longLineTopology()
  local nodes = {}
  for index = 1, 4 do
    nodes[index] = {
      x = index - 1, y = 0,
      screenX = (index - 1) * 100, screenY = 0,
      clickable = index == 1, neighbors = {},
    }
  end
  for index = 1, 4 do
    if nodes[index - 1] then table.insert(nodes[index].neighbors, nodes[index - 1]) end
    if nodes[index + 1] then table.insert(nodes[index].neighbors, nodes[index + 1]) end
  end
  return Moonpanel.Canvas.TraceTopology({
    nodes = nodes, barWidth = 10, barLength = 100, symmetry = 0,
  })
end

local function routeLength(route)
  local total = 0
  for _, segment in ipairs(route and route.segments or {}) do
    total = total + segment.visibleLength
  end
  return total
end

test.test('follower smooths authority without mutating it', function()
  local topology = lineTopology(0)
  local engine = Moonpanel.Canvas.TraceEngine(topology)
  assert(engine:start(2), 'engine did not start')
  local follower = Moonpanel.Canvas.ObserverTraceFollower(topology)
  follower:reset(engine:snapshot(), true, 0)
  engine:applySample(4096, 0, false)
  local authoritativeHash = engine:hash()
	local presentation = Moonpanel.Canvas.TracePresentation()
	presentation:beginAttempt({ sessionId = 1, revision = topology.revision }, 0)
	for step = 1, 100 do presentation:sample(step / 144) end
	assert(engine:hash() == authoritativeHash, 'presentation mutated canonical engine')
  follower:setTarget(engine:snapshot(), 1)
  local frame = follower:update(1 / 60)
  assert(engine:hash() == authoritativeHash, 'follower mutated canonical engine')
  assert(#frame.routes[1].segments == 1, 'follower did not begin extending')
  local length = frame.routes[1].segments[1].visibleLength
  assert(length > 0 and length < 100, 'follower snapped instead of smoothing')
  for _ = 1, 240 do follower:update(1 / 60) end
  assert(follower:hasReached(1), 'follower did not settle')
end)

test.test('follower smoothly completes an accessibility exit nudge', function()
  local topology = lineTopology(0)
  local partial = {
    revision = topology.revision, stacks = { { 2 } },
    active = {
      primaryFrom = 2, primaryTo = 3,
      secondaryFrom = 0, secondaryTo = 0,
      progressQ = 2048, maxProgressQ = 4096, retracting = false,
    },
    touchingExit = false,
  }
  local completed = {
    revision = topology.revision, stacks = { { 2, 3 } },
    active = false, touchingExit = false,
  }
  local follower = Moonpanel.Canvas.ObserverTraceFollower(topology)
  follower:reset(partial, true, 0)
  follower:setTarget(completed, 1)
  local frame = follower:update(1 / 60)
  local length = routeLength(frame.routes[1])
  assert(length > 50 and length < 100,
    'exit nudge snapped instead of animating to the endpoint')
  for _ = 1, 240 do follower:update(1 / 60) end
  assert(follower:hasReached(1), 'exit nudge animation never settled')
  test.near(routeLength(follower:getRenderState().routes[1]), 100, 0.000001,
    'exit nudge settled at the wrong geometry')
end)

test.test('branch changes retract to common prefix first', function()
  local topology = lineTopology(0)
  local engine = Moonpanel.Canvas.TraceEngine(topology)
  engine:start(2)
  engine:applySample(4096, 0, false)
  local follower = Moonpanel.Canvas.ObserverTraceFollower(topology)
  follower:reset(engine:snapshot(), true, 1)
  local target = engine:snapshot()
  target.stacks = { { 2 } }
  target.active = {
    primaryFrom = 2, primaryTo = 1,
    secondaryFrom = 0, secondaryTo = 0,
    progressQ = 4096, maxProgressQ = 4096, retracting = false,
  }
  follower:setTarget(target, 2)
  local frame = follower:update(1 / 60)
  assert(#frame.routes[1].segments == 1 and frame.routes[1].segments[1].token == '2:3',
    'follower changed branch before retracting')
  assert(frame.routes[1].segments[1].visibleLength < 100,
    'obsolete branch did not visibly retract')
end)

test.test('mirrored branches share one smoothing fraction', function()
  local topology = lineTopology(Moonpanel.Canvas.Symmetry.Rotational)
  local engine = Moonpanel.Canvas.TraceEngine(topology)
  assert(engine:start(2), 'symmetry engine did not start')
  local follower = Moonpanel.Canvas.ObserverTraceFollower(topology)
  follower:reset(engine:snapshot(), true, 0)
  engine:applySample(4096, 0, false)
  follower:setTarget(engine:snapshot(), 1)
  for _ = 1, 30 do
    local frame = follower:update(1 / 144)
    local primary = frame.routes[1].segments[1]
    local secondary = frame.routes[2].segments[1]
    assert(primary and secondary, 'mirrored branch missing')
    test.near(primary.visibleLength / primary.fullLength,
      secondary.visibleLength / secondary.fullLength, 0.000001,
      'mirrored fractions diverged')
  end
end)

test.test('timeline sampling is frame-rate independent', function()
  local a = Moonpanel.Canvas.TracePresentation()
  local b = Moonpanel.Canvas.TracePresentation()
  a:beginAttempt({ sessionId = 10, revision = 4 }, 100)
  b:beginAttempt({ sessionId = 10, revision = 4 }, 100)
  a:applyResult({ success = true, feedback = {} }, 100.2)
  b:applyResult({ success = true, feedback = {} }, 100.2)
  local frameA = a:sample(100.37)
  for step = 1, 30 do b:sample(100.2 + step / 300) end
  local frameB = b:sample(100.37)
  test.near(frameA.completion, frameB.completion, 0.000001, 'completion differs')
  test.near(frameA.traceAlpha, frameB.traceAlpha, 0.000001, 'alpha differs')
end)

test.test('20 Hz authoritative cadence stays smooth and bounded at render rates', function()
  for _, fps in ipairs({ 20, 30, 60, 144, 300 }) do
    local topology = lineTopology(0)
    local engine = Moonpanel.Canvas.TraceEngine(topology)
    assert(engine:start(2), 'cadence engine did not start')
    local follower = Moonpanel.Canvas.ObserverTraceFollower(topology)
    follower:reset(engine:snapshot(), true, 0)
    local previousLength = 0
    for sequence = 1, 10 do
      engine:applySample(410, 0, false)
      local target = Moonpanel.Canvas.BuildTraceRenderState(topology, engine:snapshot(), sequence)
      local targetSegment = target.routes[1].segments[1]
      local targetLength = targetSegment and targetSegment.visibleLength or 0
      follower:setTarget(engine:snapshot(), sequence)
      for _ = 1, math.max(1, math.floor(fps * 0.05 + 0.5)) do
        local frame = follower:update(1 / fps)
        local segment = frame.routes[1].segments[1]
        local displayedLength = segment and segment.visibleLength or 0
        assert(displayedLength + 0.000001 >= previousLength,
          'forward follower moved backward at ' .. fps .. ' FPS')
        assert(displayedLength <= targetLength + 0.000001,
          'follower rendered beyond authority at ' .. fps .. ' FPS')
        previousLength = displayedLength
      end
    end
    for _ = 1, fps * 2 do follower:update(1 / fps) end
    assert(follower:hasReached(10), 'cadence follower did not settle at ' .. fps .. ' FPS')
  end
end)

test.test('failure and eraser feedback style whole symbols on seekable timelines', function()
  local failure = Moonpanel.Canvas.TracePresentation()
  failure:beginAttempt({ sessionId = 1, revision = 1 }, 10)
  failure:applyResult({
    success = false,
    feedback = { violations = { 7 }, remaining = { 7 }, erasures = {} },
  }, 10.2)
  local failureFrame, failureCues = failure:sample(10.5)
  assert(failureFrame.entityStyles[7] and failureFrame.entityStyles[7].error > 0,
    'remaining invalid symbol did not receive an error style')
  assert(failureFrame.traceError > 0 and failureFrame.traceAlpha < 1,
    'failure did not transition and fade the trace')
  assert(#failureCues > 0, 'failure transition emitted no cues')
  local failureSoundQueued = false
  for _, cue in ipairs(failureCues) do failureSoundQueued = cue == 'Failure' or failureSoundQueued end
  assert(failureSoundQueued, 'failure sound cue was not queued')
  local _, repeatedCues = failure:sample(10.5)
  assert(#repeatedCues == 0, 'failure cues replayed on repeated sampling')

  local erased = Moonpanel.Canvas.TracePresentation()
  erased:beginAttempt({ sessionId = 2, revision = 1 }, 20)
  erased:applyResult({
    success = true,
    feedback = {
      violations = { 11 }, remaining = {},
      erasures = { { eraserIndex = 5, targetIndex = 11 } },
    },
  }, 20.2)
  local reveal = erased:sample(20.6)
  assert(reveal.entityStyles[11] and reveal.entityStyles[11].error > 0,
    'pre-erasure violation was not revealed')
  local applied = erased:sample(21.2)
  assert(applied.entityStyles[5] and applied.entityStyles[5].erased > 0 and
    applied.entityStyles[11] and applied.entityStyles[11].erased > 0,
    'eraser and target were not styled as complete erased symbols')
  assert(applied.entityStyles[5].alpha >= 0.25 and
    applied.entityStyles[11].alpha >= 0.25,
    'erased symbols faded below quarter opacity')
  assert(applied.completion > 0, 'eraser success did not continue into completion')

  local erasedSettled = erased:sample(
    20.2 + Moonpanel.Canvas.PresentationConstants.EraserReveal +
    Moonpanel.Canvas.PresentationConstants.EraserFade)
  assert(erasedSettled.entityStyles[5].alpha == 0.25 and
    erasedSettled.entityStyles[11].alpha == 0.25,
    'erased symbols did not settle at quarter opacity')

  local rejected = Moonpanel.Canvas.TracePresentation()
  rejected:beginAttempt({ sessionId = 3, revision = 1 }, 30)
  rejected:applyResult({
    success = false,
    feedback = {
      violations = { 11, 12 }, remaining = { 12 },
      erasures = { { eraserIndex = 5, targetIndex = 11 } },
    },
  }, 30.2)
  local reveal, revealCues = rejected:sample(
    30.2 + Moonpanel.Canvas.PresentationConstants.EraserReveal)
  local failureSoundQueued = false
  for _, cue in ipairs(revealCues) do failureSoundQueued = cue == 'Failure' or failureSoundQueued end
  assert(failureSoundQueued,
    'eraser-backed hexagon failure did not emit the failure sound at reveal')
  local settled = rejected:sample(
    30.2 + Moonpanel.Canvas.PresentationConstants.EraserReveal +
    Moonpanel.Canvas.PresentationConstants.ErrorLifetime)
  local remainingStyle = settled.entityStyles[12]
  assert(not remainingStyle or remainingStyle.error == 0,
    'eraser failure left a remaining symbol permanently red')
  assert(not settled.needsAnimation and not settled.needsSampling,
    'eraser failure did not settle on its clean terminal frame')

  local stillAnimating = rejected:sample(
    30.2 + Moonpanel.Canvas.PresentationConstants.EraserReveal + 3)
  assert(stillAnimating.needsAnimation,
    'error animation did not remain active for its extended lifetime')
end)

test.test('exit cues fire once per contact transition and can restart', function()
  local presentation = Moonpanel.Canvas.TracePresentation()
  presentation:beginAttempt({ sessionId = 3, revision = 1 }, 30)
  presentation:sample(30)
  assert(presentation:setExitContact(true, 30.1), 'first contact was ignored')
  local _, entered = presentation:sample(30.1)
  assert(#entered == 2 and entered[1] == 'FinishTracing' and
    entered[2] == 'PathCompleteStart', 'enter cues were wrong')
  assert(not presentation:setExitContact(true, 30.11), 'duplicate contact changed state')
  local _, duplicate = presentation:sample(30.11)
  assert(#duplicate == 0, 'duplicate contact replayed cues')
  presentation:setExitContact(false, 30.2)
  presentation:sample(30.2)
  presentation:setExitContact(true, 30.3)
  local _, reentered = presentation:sample(30.3)
  assert(#reentered == 2 and reentered[1] == 'FinishTracing',
    're-entering the exit did not restart transition cues')
end)

test.test('canonical render state preserves committed and active geometry', function()
  local topology = longLineTopology()
  local snapshot = {
    revision = topology.revision,
    stacks = { { 1, 2, 3 } },
    active = {
      primaryFrom = 3, primaryTo = 4,
      secondaryFrom = 0, secondaryTo = 0,
      progressQ = 1024, maxProgressQ = 2048, retracting = false,
    },
    touchingExit = false,
  }
  local state = Moonpanel.Canvas.BuildTraceRenderState(topology, snapshot, 41)
  assert(state.sequence == 41 and #state.routes[1].segments == 3,
    'render state omitted canonical segments')
  assert(state.routes[1].segments[1].token == '1:2' and
    state.routes[1].segments[3].token == '3:4', 'segment tokens were unstable')
  test.near(state.routes[1].segments[3].visibleLength, 25, 0.000001,
    'active progress was converted incorrectly')
end)

test.test('follower frame delta is clamped and can cross segment boundaries', function()
  local topology = longLineTopology()
  local start = { revision = topology.revision, stacks = { { 1 } }, active = false }
  local target = {
    revision = topology.revision,
    stacks = { { 1, 2, 3 } },
    active = {
      primaryFrom = 3, primaryTo = 4,
      secondaryFrom = 0, secondaryTo = 0,
      progressQ = 2048, maxProgressQ = 4096, retracting = false,
    },
  }
  local clamped = Moonpanel.Canvas.ObserverTraceFollower(topology)
  local reference = Moonpanel.Canvas.ObserverTraceFollower(topology)
  clamped:reset(start, true, 0)
  reference:reset(start, true, 0)
  clamped:setTarget(target, 1)
  reference:setTarget(target, 1)
  local burst = clamped:update(1)
  local normal = reference:update(1 / 15)
  test.near(routeLength(burst.routes[1]), routeLength(normal.routes[1]), 0.000001,
    'large frame delta bypassed the clamp')
  assert(#burst.routes[1].segments == 2,
    'one smoothing budget could not cross a segment boundary')
  assert(routeLength(burst.routes[1]) < 250,
    'burst smoothing rendered beyond the canonical target')
end)

test.test('same-session correction retracts smoothly without snapping', function()
  local topology = longLineTopology()
  local full = {
    revision = topology.revision, stacks = { { 1, 2, 3 } },
    active = {
      primaryFrom = 3, primaryTo = 4,
      secondaryFrom = 0, secondaryTo = 0,
      progressQ = 2048, maxProgressQ = 4096, retracting = false,
    },
  }
  local corrected = { revision = topology.revision, stacks = { { 1, 2 } }, active = false }
  local follower = Moonpanel.Canvas.ObserverTraceFollower(topology)
  follower:reset(full, true, 10)
  follower:setTarget(corrected, 11)
  local frame = follower:update(1 / 60)
  local length = routeLength(frame.routes[1])
  assert(length > 100 and length < 250, 'same-session correction snapped')
  assert(not follower:hasReached(11), 'correction reported completion too early')
  for _ = 1, 240 do follower:update(1 / 60) end
  assert(follower:hasReached(11), 'correction never settled')
  test.near(routeLength(follower:getRenderState().routes[1]), 100, 0.000001,
    'corrected route settled at the wrong geometry')
end)

test.test('observer follower never renders beyond a constrained authority head', function()
  local topology = longLineTopology()
  local start = { revision = topology.revision, stacks = { { 1 } }, active = false }
  local constrained = {
    revision = topology.revision,
    stacks = { { 1 } },
    active = {
      primaryFrom = 1, primaryTo = 2,
      secondaryFrom = 0, secondaryTo = 0,
      progressQ = 1024, maxProgressQ = 4096, retracting = false,
    },
  }
  local follower = Moonpanel.Canvas.ObserverTraceFollower(topology)
  follower:reset(start, true, 0)
  follower:setTarget(constrained, 1)
  for _ = 1, 240 do
    local frame = follower:update(1 / 60)
    assert(routeLength(frame.routes[1]) <= 25.000001,
      'observer follower crossed the authoritative obstacle limit')
  end
  assert(follower:hasReached(1), 'constrained observer target never settled')
  test.near(routeLength(follower:getRenderState().routes[1]), 25, 0.000001,
    'observer settled at the wrong constrained progress')
end)

test.test('late terminal seeking is silent and samples elapsed state', function()
  local presentation = Moonpanel.Canvas.TracePresentation()
  presentation:beginAttempt({ sessionId = 99, revision = 7 }, 100)
  presentation:applyResult({
    success = false,
    eventSerial = 8,
    feedback = { violations = { 3 }, remaining = { 3 }, erasures = {} },
  }, 101, 1.2, true)
  local frame, cues = presentation:sample(101)
  assert(#cues == 0, 'late join replayed historical sounds')
  assert(frame.traceAlpha == 0, 'late join did not seek the failure fade')
  assert(frame.entityStyles[3] ~= nil, 'late join omitted active error styling')

  local eraser = Moonpanel.Canvas.TracePresentation()
  eraser:beginAttempt({ sessionId = 100, revision = 7 }, 100)
  eraser:applyResult({
    success = false,
    feedback = {
      violations = { 3, 4 }, remaining = { 4 },
      erasures = { { eraserIndex = 2, targetIndex = 3 } },
    },
  }, 101, 1.2, true)
  local eraserFrame, eraserCues = eraser:sample(101)
  assert(#eraserCues == 0, 'late eraser result replayed historical sounds')
  assert(eraserFrame.traceAlpha < 1, 'late failed eraser trace did not fade')
  assert(eraserFrame.entityStyles[4] and eraserFrame.entityStyles[4].error > 0,
    'late failed eraser result did not blink its remaining error')
end)

test.test('settled observer follower reports no visual changes', function()
  local topology = lineTopology(0)
  local engine = Moonpanel.Canvas.TraceEngine(topology)
  assert(engine:start(2), 'engine did not start')
  local snapshot = engine:snapshot()
  local follower = Moonpanel.Canvas.ObserverTraceFollower(topology)
  follower:reset(snapshot, true, 4)

  local initial = follower:getRenderState()
  local current, changed = follower:update(1 / 60)
  assert(current == initial, 'settled follower replaced its render state')
  assert(changed == false, 'settled follower dirtied an unchanged frame')
	assert(follower.settled == true, 'seeded follower was not marked quiescent')

  follower:setTarget(snapshot, 5)
  current, changed = follower:update(1 / 60)
  assert(current == initial, 'sequence-only target replaced render geometry')
  assert(changed == false, 'sequence-only target reported a visual change')
  assert(follower:hasReached(5), 'sequence-only target did not settle')
	assert(follower.settled == true, 'sequence-only target remained active')
end)

test.test('terminal presentation becomes quiescent after its final frame', function()
  local presentation = Moonpanel.Canvas.TracePresentation()
  presentation:beginAttempt({ id = 1, revision = 1 }, 0)
  presentation:applyResult({ success = true, feedback = {} }, 0)

  local active = presentation:sample(0.1)
  assert(active.needsAnimation and active.needsSampling,
    'active success transition was marked quiescent')

  local settled = presentation:sample(1)
  assert(not settled.needsAnimation and not settled.needsSampling,
    'completed success transition still requests per-frame sampling')
end)

test.test('active presentation expands scint rings until their power expires', function()
  local presentation = Moonpanel.Canvas.TracePresentation()
  presentation:beginAttempt({ id = 1, revision = 1 }, 0)

  local expanding = presentation:sample(1)
  assert(expanding.needsAnimation and expanding.needsSampling and
      expanding.scintProgress > 0 and expanding.scintAlpha > 0,
    'scint ring did not remain active while expanding')

  local settled = presentation:sample(15)
  assert(not settled.needsAnimation and not settled.needsSampling,
    'expired scint sequence still requests per-frame sampling')

  presentation:setExitContact(true, 13)
  local exitFrame = presentation:sample(13.05)
  assert(exitFrame.needsAnimation and exitFrame.needsSampling,
    'exit contact did not wake a settled presentation')
end)

test.test('focus hint scinting targets starts before tracing and exits during tracing', function()
  local presentation = Moonpanel.Canvas.TracePresentation()
  presentation:setFocusHint(true, 0)

  local hint = presentation:sample(1)
  assert(hint.scintStarts and hint.scintAlpha > 0,
    'focused empty panel did not scint its start points')

  presentation:beginAttempt({ id = 2, revision = 1 }, 0)
  local active = presentation:sample(1)
  assert(not active.scintStarts and active.scintAlpha > 0,
    'active trace still scinted start points')
end)

test.test('start scint rearms only after focus is left and re-entered', function()
  local presentation = Moonpanel.Canvas.TracePresentation()
  presentation:setFocusHint(true, 0)
  presentation:beginAttempt({ id = 1, revision = 1 }, 0)
  presentation:reset('clean-attempt')
  local consumed = presentation:sample(CurTime() + 1)
  assert(not consumed.scintStarts and consumed.scintAlpha == 0,
    'completed focus session restarted its start-point scint')
  presentation:setFocusHint(false, CurTime() + 2)
  presentation:setFocusHint(true, CurTime() + 3)
  local restarted = presentation:sample(CurTime() + 4)
  assert(restarted.scintStarts and restarted.scintAlpha > 0,
    'new focus session did not restart its start-point scint')
end)

test.test('branch visibility and colors are carried by visual frames', function()
  local presentation = Moonpanel.Canvas.TracePresentation()
  local primary = { r = 255, g = 255, b = 255 }
  local secondary = { r = 255, g = 255, b = 0 }
  presentation:setBranches({
    { visible = true, color = primary, completionColor = { r = 100, g = 100, b = 100 } },
    { visible = false, color = secondary, completionColor = { r = 100, g = 100, b = 0 } },
  })
  presentation:beginAttempt({ id = 1, revision = 1 }, 0)
  local frame = presentation:sample(1)
  assert(frame.branchStyles[1].color == primary and frame.branchStyles[1].visible,
    'primary branch style was not retained')
  assert(frame.branchStyles[2].color == secondary and not frame.branchStyles[2].visible,
    'invisible branch style was not retained')
end)

test.run()
