local test = dofile('tools/tests/harness.lua')
dofile('dest/lua/moonpanel/canvas/sh_helpers.lua')
local Document = dofile('dest/lua/moonpanel/canvas/editor/cl_document.lua')

local function newDocument(data, writes)
  writes = writes or {}
  return Document.New(data or { value = 1 }, {
    historyLimit = 3,
    sanitize = function(value) return value end,
    writeFile = function(path, value)
      writes.file = { path = path, data = value }
      return true
    end,
    writeRecovery = function(value, metadata)
      writes.recovery = { data = value, metadata = metadata }
      return true, 42
    end,
    writeSession = function(path)
      writes.sessionPath = path
      return true
    end,
  }), writes
end

test.test('fresh panel has one start and one exit at opposite corners', function()
  local fresh = Document.FreshPanel(function(data) return data end)
  assert(fresh.Meta.Width == 3 and fresh.Meta.Height == 3)
  assert(fresh.Entities[7].Type == 'End' and fresh.Entities[43].Type == 'Start')
  local count = 0
  for _ in pairs(fresh.Entities) do count = count + 1 end
  assert(count == 2, 'fresh panel contains extra authored clues')
end)

test.test('document transactions drive dirty state and undo redo', function()
  local document = newDocument({ value = 1 })
  document:BeginEdit('change value')
  assert(document:CommitEdit({ value = 2 }))
  assert(document:IsDirty() and document:CanUndo() and not document:CanRedo())
  assert(document:Undo() and document:GetData().value == 1)
  assert(not document:IsDirty() and document:CanRedo())
  assert(document:Redo() and document:GetData().value == 2)
end)

test.test('opening a clean document persists its path without recovery', function()
  local document, writes = newDocument({ value = 1 })
  document:Replace({ value = 2 }, {
    resetHistory = true, markSaved = true, path = 'moonpanel/a.txt',
  })
  assert(writes.sessionPath == 'moonpanel/a.txt',
    'clean opened path was not persisted')
  assert(writes.recovery == nil and not document:IsDirty(),
    'opening a clean document wrote dirty recovery state')
end)

test.test('matching merge keys coalesce and new edits invalidate redo', function()
  local document = newDocument({ value = 0 })
  document:BeginEdit('slider', 'width')
  document:CommitEdit({ value = 1 })
  document:BeginEdit('slider', 'width')
  document:CommitEdit({ value = 2 })
  assert(#document.history == 1 and document.history[1].before.value == 0)
  document:Undo()
  document:BeginEdit('different')
  document:CommitEdit({ value = 3 })
  assert(not document:CanRedo() and document:GetData().value == 3)
end)

test.test('independent preset-style edits remain separate history entries', function()
  local document = newDocument({ value = 0 })
  document:BeginEdit('Apply color preset')
  document:CommitEdit({ value = 1 })
  document:BeginEdit('Apply color preset')
  document:CommitEdit({ value = 2 })
  assert(#document.history == 2,
    'separate preset choices must not collapse into one undo step')
  assert(document:Undo() and document:GetData().value == 1)
  assert(document:Undo() and document:GetData().value == 0)
end)

test.test('built-in documents remain read-only until Save As', function()
  local document, writes = newDocument({ value = 1 })
  document:Replace({ value = 4 }, {
    resetHistory = true, markSaved = true, clearPath = true,
    source = { kind = 'builtin', id = 'thewitness/colors/1' },
  })
  assert(document:IsReadOnly() and document:GetSource().kind == 'builtin',
    'built-in source state was not retained')
  local saved = document:Save()
  assert(not saved, 'built-in document allowed direct overwrite')
  document:BeginEdit('change built-in')
  document:CommitEdit({ value = 5 })
  assert(document:IsDirty(), 'editing a built-in did not mark it dirty')
  assert(document:SaveAs('moonpanel/copied.txt'))
  assert(not document:IsReadOnly() and document:GetPath() == 'moonpanel/copied.txt' and
    not document:IsDirty() and writes.file.path == 'moonpanel/copied.txt',
    'Save As did not convert the built-in to a writable document')
end)

test.test('history limit retains the most recent reversible edits', function()
  local document = newDocument({ value = 0 })
  for value = 1, 5 do
    document:BeginEdit('change ' .. value)
    document:CommitEdit({ value = value })
  end
  assert(#document.history == 3)
  document:Undo(); document:Undo(); document:Undo()
  assert(document:GetData().value == 2)
end)

test.test('save establishes a clean baseline and recovery never saves the file', function()
  local document, writes = newDocument({ nested = { value = 1 } })
  document:BeginEdit('change')
  document:CommitEdit({ nested = { value = 2 } })
  assert(document:Save('moonpanel/test.txt'))
  assert(not document:IsDirty() and writes.file.path == 'moonpanel/test.txt')
  assert(not document:WriteRecovery() and not writes.recovery,
    'clean document produced an autosave')
  document:BeginEdit('change')
  document:CommitEdit({ nested = { value = 3 } })
  assert(document:WriteRecovery())
  assert(writes.recovery.data.nested.value == 3)
  assert(writes.file.data.nested.value == 2)
  writes.recovery.data.nested.value = 99
  assert(document:GetData().nested.value == 3, 'write adapter aliased live data')
end)

test.test('selection and placement presets cannot alias caller tables', function()
  local document = newDocument({ value = 1 })
  assert(document.activeTool == 'place', 'place must be the safe default editor tool')
  local preset = { Data = { Shape = { { 1 } } } }
  document:SetPlacementPreset(preset)
  preset.Data.Shape[1][1] = 0
  local output = document:GetPlacementPreset()
  assert(output.Data.Shape[1][1] == 1)
  output.Data.Shape[1][1] = 0
  assert(document:GetPlacementPreset().Data.Shape[1][1] == 1)
  assert(document:SetSelection(8.8) == 8)
end)

test.test('semantic clue equality ignores legacy tint and polyomino padding', function()
  Moonpanel.Color = { Black = 1, Yellow = 2, Orange = 3 }
  Moonpanel.Canvas.DotRole = { Any = 0, Primary = 1, Secondary = 2 }
  local padded = {
    Type = 'Polyomino',
    Data = {
      RuleColor = 2,
      TintColor = 4,
      Shape = { { 0, 0, 0 }, { 0, 1, 0 }, { 0, 1, 0 } },
      Rotational = false,
      Negative = false,
    },
  }
  local compact = {
    Type = 'Polyomino',
    Data = {
      RuleColor = 2,
      Color = 4,
      Shape = { { 1 }, { 1 } },
      Rotational = false,
      Negative = false,
    },
  }
  assert(Document.SemanticEqual(padded, compact),
    'equivalent padded and legacy-tint clues should compare equal')
end)

test.test('on-demand loading happens once', function()
  local reads = 0
  local document = Document.New(nil, {
    sanitize = function(value) return value end,
    load = function()
      reads = reads + 1
      return { value = 7 }, { path = 'moonpanel/lazy.txt', saved = true }
    end,
  })
  local data, loaded = document:LoadOnDemand()
  assert(loaded and data.value == 7 and document.currentPath == 'moonpanel/lazy.txt')
  document:LoadOnDemand()
  assert(reads == 1)
end)

test.test('cancel restores the transaction without adding history', function()
  local document = newDocument({ value = 1 })
  document:BeginEdit('preview')
  assert(document:CancelEdit())
  assert(document:GetData().value == 1 and #document.history == 0)
end)

test.run()
