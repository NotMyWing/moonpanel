local function runStore(exists, serializedData, initialData)
  CLIENT = true
  Moonpanel = {}
  dofile('dest/lua/moonpanel/canvas/sh_helpers.lua')
  Moonpanel = {
    Editor = initialData and { CurrentData = initialData } or {},
    EditorDocument = dofile('dest/lua/moonpanel/canvas/editor/sh_document.lua'),
    Canvas = {
      SampleData = { source = 'sample' },
      SanitizeData = function(data)
        return { source = data.source, sanitized = true }
      end,
      DeserializeData = function(contents)
        if contents == 'valid' then return serializedData end
        return nil
      end,
    },
  }
  file = {
    Exists = function(path, realm)
      if path == 'moonpanel/autosave.meta.txt' then return false end
      assert(path == 'moonpanel/autosave.txt' and realm == 'DATA')
      return exists
    end,
    Read = function(path, realm)
      if path == 'moonpanel/autosave.meta.txt' then return nil end
      assert(path == 'moonpanel/autosave.txt' and realm == 'DATA')
      return exists and (serializedData and 'valid' or 'corrupt') or nil
    end,
  }
  util = {
    JSONToTable = function() return nil end,
    TableToJSON = function() return '{}' end,
  }
  dofile('dest/lua/moonpanel/canvas/editor/cl_store.lua')
  return Moonpanel.Editor
end

local test = dofile('tools/tests/harness.lua')

test.test('stored panel loads on first request without opening the editor UI', function()
  local editor = runStore(true, { source = 'autosave' })
	assert(not editor.StoredDataLoaded, 'store performed eager startup I/O')
  assert(editor:GetCurrentData().source == 'autosave',
    'network/tool reads did not receive stored data')
	assert(editor.StoredDataLoaded and editor.CurrentData.source == 'autosave' and
		editor.CurrentData.sanitized, 'first request did not initialize storage')
end)

test.test('missing autosave falls back to the sample panel', function()
  local editor = runStore(false)
	editor:EnsureStoredDataLoaded()
  assert(editor.CurrentData.source == 'sample', 'sample fallback was not selected')
end)

test.test('corrupt autosave preserves an existing in-memory panel', function()
  local editor = runStore(true, nil, { source = 'memory' })
	editor:EnsureStoredDataLoaded()
  assert(editor.CurrentData.source == 'memory', 'corrupt storage discarded current data')
end)

test.test('non-forced reads do not repeatedly hit disk', function()
  local editor = runStore(true, { source = 'autosave' })
	editor:EnsureStoredDataLoaded()
  local reads = 0
  file.Read = function() reads = reads + 1 return 'valid' end
  editor:EnsureStoredDataLoaded()
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
