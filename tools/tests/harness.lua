dofile('tools/tests/bootstrap.lua')

local Harness = {
  tests = {},
}

function Harness.test(name, callback)
  table.insert(Harness.tests, { name = name, callback = callback })
end

function Harness.near(actual, expected, epsilon, message)
  epsilon = epsilon or 0.000001
  assert(math.abs(actual - expected) <= epsilon,
    (message or 'values differ') .. string.format(' (%.9f ~= %.9f)', actual, expected))
end

function Harness.run()
  local failed = 0
  for _, entry in ipairs(Harness.tests) do
    local ok, reason = xpcall(entry.callback, debug.traceback)
    if not ok then
      failed = failed + 1
      io.stderr:write('\nFAIL: ' .. entry.name .. '\n' .. reason .. '\n')
    end
  end

  if failed > 0 then
    error(string.format('%d/%d tests failed', failed, #Harness.tests), 0)
  end

  io.stdout:write(string.format('PASS: %d tests\n', #Harness.tests))
end

dofile('dest/lua/moonpanel/canvas/sh_helpers.lua')

return Harness
