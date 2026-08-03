local function runStore(exists, serializedData, initialData, metadata, openedData)
  CLIENT = true
  Moonpanel = {}
  dofile('dest/lua/moonpanel/canvas/sh_helpers.lua')
  local editor = initialData and { CurrentData = initialData } or {}
  editor.LoadBuiltInPanel = function(_, id)
    return { source = 'builtin:' .. id }
  end
  Moonpanel = {
    Editor = editor,
    EditorDocument = dofile('dest/lua/moonpanel/canvas/editor/cl_document.lua'),
    Canvas = {
      SanitizeData = function(data)
        return {
          source = data.source or (data.Meta and 'fresh'),
          sanitized = true,
        }
      end,
      DeserializeData = function(contents)
        if contents == 'valid' then return serializedData end
        if contents == 'opened' then return openedData end
        return nil
      end,
    },
  }
  TEST_FILE_STATE = {exists = exists, serializedData = serializedData,
    metadata = metadata, openedData = openedData}
  dofile('dest/lua/moonpanel/canvas/editor/cl_store.lua')
  return Moonpanel.Editor
end

local test = dofile('tools/tests/harness.lua')

test.test('stored panel loads on first request without opening the editor UI', function()
  local editor = runStore(true, { source = 'autosave' })
	assert(not editor.Document, 'store performed eager startup I/O')
  assert(editor:GetCurrentData().source == 'autosave',
    'network/tool reads did not receive stored data')
	assert(editor.Document.loaded and editor:GetCurrentData().sanitized,
		'first request did not initialize storage')
end)

test.test('missing autosave creates a fresh panel', function()
  local editor = runStore(false)
	editor:GetCurrentData()
  assert(editor:GetCurrentData().source == 'fresh', 'fresh fallback was not selected')
end)

test.test('clean session metadata reopens its document instead of stale recovery', function()
  local editor = runStore(true, { source = 'stale' }, nil, {
    path = 'moonpanel/opened.txt', dirty = false,
  }, { source = 'opened' })
  assert(editor:GetCurrentData().source == 'opened',
    'clean session did not reopen its last document')
  assert(editor.Document:GetPath() == 'moonpanel/opened.txt' and
    not editor.Document:IsDirty(), 'reopened document lost clean path metadata')
end)

test.test('clean session metadata reopens a built-in panel read-only', function()
  local editor = runStore(false, nil, nil, {
    dirty = false,
    source = { kind = 'builtin', id = 'thewitness/colors/1' },
  })
  local data = editor:GetCurrentData()
  assert(data.source == 'builtin:thewitness/colors/1',
    'clean session did not reopen its built-in panel')
  assert(editor.Document:IsReadOnly() and editor.Document:GetSource().kind == 'builtin',
    'reopened built-in panel was not marked read-only')
end)

test.test('corrupt autosave preserves an existing in-memory panel', function()
  local editor = runStore(true, nil, { source = 'memory' })
	editor:GetCurrentData()
  assert(editor:GetCurrentData().source == 'memory', 'corrupt storage discarded current data')
end)

test.test('non-forced reads do not repeatedly hit disk', function()
  local editor = runStore(true, { source = 'autosave' })
	editor:GetCurrentData()
  local reads = 0
  file.Read = function() reads = reads + 1 return 'valid' end
  editor:GetCurrentData()
  editor:GetCurrentData()
  assert(reads == 0, 'initialized storage was read repeatedly')
end)

test.test('current data comes from the live dirty document', function()
  local editor = runStore(true, { source = 'autosave' })
  editor:GetCurrentData()
  local document = editor:EnsureDocument()
  document:BeginEdit('dirty in-memory panel')
  document:CommitEdit({ source = 'dirty' })

  local current = editor:GetCurrentData()
  assert(document:IsDirty(), 'in-memory edit unexpectedly became saved')
  assert(current.source == 'dirty' and current.sanitized,
    'panel requests did not receive the dirty in-memory document')

  current.source = 'aliased'
  assert(editor:GetCurrentData().source == 'dirty',
    'current panel data aliased the editor document')
end)

test.run()
