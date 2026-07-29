local function runStore(exists, serializedData, initialData, metadata, openedData)
  CLIENT = true
  Moonpanel = {}
  dofile('dest/lua/moonpanel/canvas/sh_helpers.lua')
  Moonpanel = {
    Editor = initialData and { CurrentData = initialData } or {},
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
  file = {
    Exists = function(path, realm)
      assert(realm == 'DATA')
      if path == 'moonpanel/autosave.meta.txt' then return metadata ~= nil end
      if path == 'moonpanel/autosave.txt' then return exists end
      return metadata and path == metadata.path and openedData ~= nil
    end,
    Read = function(path, realm)
      assert(realm == 'DATA')
      if path == 'moonpanel/autosave.meta.txt' then return 'metadata' end
      if path == 'moonpanel/autosave.txt' then
        return exists and (serializedData and 'valid' or 'corrupt') or nil
      end
      return metadata and path == metadata.path and openedData and 'opened' or nil
    end,
  }
  util = {
    JSONToTable = function(contents) return contents == 'metadata' and metadata or nil end,
    TableToJSON = function() return '{}' end,
  }
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
