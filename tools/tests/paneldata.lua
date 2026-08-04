local test = dofile('tools/tests/harness.lua')

dofile('dest/lua/moonpanel/sh_colors.lua')
dofile('dest/lua/moonpanel/canvas/sh_helpers.lua')
local flatIndex = Moonpanel.Helpers.flatIndex
dofile('dest/lua/moonpanel/canvas/sh_paneldata.lua')

test.test('canonical blue is pure RGB blue', function()
  local blue = Moonpanel.Canvas.ColorValues[Moonpanel.Color.Blue]
  assert(blue and blue.r == 0 and blue.g == 0 and blue.b == 255,
    'canonical Blue is not #0000ff')
end)


local function base(version)
  local entities = {}
  for index = 1, 9 do entities[index] = {} end
  return {
    SchemaVersion = version,
    Meta = {
      Width = 1,
      Height = 1,
      Symmetry = Moonpanel.Canvas.Symmetry.None,
      SymmetryOptions = {
        Colorful = false,
        Traces = {
          {Color = Moonpanel.Color.Cyan},
          {Color = Moonpanel.Color.Magenta},
        },
      },
    },
    Entities = entities,
  }
end

test.test('panel appearance uses the canonical defaults', function()
  local clean = Moonpanel.Canvas.SanitizeData(base(Moonpanel.Canvas.SchemaVersion))
  local colors = clean.Colors
  assert(colors.Untraced.r == 31 and colors.Untraced.g == 7 and colors.Untraced.b == 159,
    'canonical grid default was not applied')
  assert(colors.Background.r == 80 and colors.Vignette.a == 80,
    'canonical appearance defaults were not applied')
  assert(colors.Cell == nil, 'missing authored Cell color was synthesized')
end)

test.test('authored Cell color is preserved and optional presets stay optional', function()
  local authored = base(Moonpanel.Canvas.SchemaVersion)
  authored.Colors = {}
  authored.Colors.Cell = {r = 1, g = 2, b = 3, a = 255}
  local clean = Moonpanel.Canvas.SanitizeData(authored)
  assert(clean.Colors.Cell.r == 1 and clean.Colors.Cell.g == 2 and clean.Colors.Cell.b == 3,
    'authored Cell color was not preserved')
  authored.Colors.Cell = table.Copy(Moonpanel.Canvas.DefaultColors.Cell)
  assert(Moonpanel.Canvas.SanitizeData(authored).Colors.Cell ~= nil,
    'current authored default Cell color was mistaken for a legacy sentinel')
  assert(Moonpanel.Canvas.ResolveColorPreset('Default').Cell == nil,
    'default preset unexpectedly enabled Cell')
  assert(Moonpanel.Canvas.ResolveColorPreset('The Quarry Gray').Cell ~= nil,
    'explicit Cell preset did not enable Cell')
  local swamp = Moonpanel.Canvas.ResolveColorPreset('Swamp 1')
  assert(swamp.Background.r == 44 and swamp.Background.g == 55 and swamp.Background.b == 0,
    'Swamp 1 background is incorrect')
  assert(swamp.Cell.r == 74 and swamp.Untraced.r == 95 and swamp.Traced.g == 171 and swamp.Finished.r == 157,
    'Swamp 1 colors are incorrect')

  local windmill = Moonpanel.Canvas.ResolveColorPreset('The Windmill')
  assert(Moonpanel.Canvas.ColorPresets['The Windmill'].Cell == nil,
    'Windmill must not author the optional Cell role')
  assert(windmill.Cell == nil,
    'Windmill unexpectedly enabled the optional Cell role')
  assert(Moonpanel.Canvas.SanitizeData({
    SchemaVersion = Moonpanel.Canvas.SchemaVersion,
    Meta = base(Moonpanel.Canvas.SchemaVersion).Meta,
    Entities = {},
    Colors = windmill,
  }).Colors.Cell == nil,
    'Windmill application did not leave Cell absent after sanitization')

  local legacyDefault = base(7)
  legacyDefault.Colors = {Cell = table.Copy(Moonpanel.Canvas.DefaultColors.Cell)}
  assert(Moonpanel.Canvas.SanitizeData(legacyDefault).Colors.Cell == nil,
    'the historical synthesized Cell default was not removed')
  legacyDefault.Colors.Cell = {r = 0, g = 0, b = 0, a = 0}
  assert(Moonpanel.Canvas.SanitizeData(legacyDefault).Colors.Cell == nil,
    'the historical transparent Cell sentinel was not removed')
end)

test.test('per-trace completion colors are optional and preserved', function()
  local clean = Moonpanel.Canvas.SanitizeData(base(Moonpanel.Canvas.SchemaVersion))
  assert(clean.Meta.SymmetryOptions.Traces[1].CompletionColorValue == nil,
    'completion color was synthesized')
  local authored = base(Moonpanel.Canvas.SchemaVersion)
  authored.Meta.SymmetryOptions.Traces[2].CompletionColorValue = {r = 1, g = 2, b = 3, a = 255}
  local sanitized = Moonpanel.Canvas.SanitizeData(authored)
  local color = sanitized.Meta.SymmetryOptions.Traces[2].CompletionColorValue
  assert(color.r == 1 and color.g == 2 and color.b == 3,
    'authored per-trace completion color was not preserved')
end)

test.test('terminal color helper increases chroma for ordinary traces', function()
  local terminal = Moonpanel.Helpers.terminalColor({r = 231, g = 98, b = 92, a = 255})
  assert(terminal.r > terminal.g * 3 and terminal.r > terminal.b * 3,
    'terminal color helper did not produce a saturated red')
end)

test.test('historical color presets resolve against modern defaults', function()
  local preset = Moonpanel.Canvas.ResolveColorPreset('The Challenge Triangles')
  assert(preset.Background.r == 30 and preset.Traced.g == 160 and preset.Untraced.b == 50,
    'historical preset overrides were not resolved')
  assert(preset.Finished.r == Moonpanel.Canvas.DefaultColors.Finished.r,
    'partial preset did not retain the modern default for omitted roles')

  local default = Moonpanel.Canvas.ResolveColorPreset('Default')
  assert(default.Untraced.r == 31 and default.Untraced.g == 7 and default.Untraced.b == 159,
    'Default preset reverted to the historical grid color')
end)

test.test('resolved color presets are independent copies', function()
  local first = Moonpanel.Canvas.ResolveColorPreset('The Windmill')
  local second = Moonpanel.Canvas.ResolveColorPreset('The Windmill')
  first.Background.r = 1
  assert(second.Background.r == 112, 'resolved presets share mutable color state')
  assert(Moonpanel.Canvas.DefaultColors.Background.r == 80,
    'resolved preset mutation changed canonical defaults')
end)

test.test('unknown color presets are rejected', function()
  assert(Moonpanel.Canvas.ResolveColorPreset('Missing preset') == nil,
    'unknown preset did not return nil')
end)

test.test('sound presets default and reject unknown identities', function()
  local clean = Moonpanel.Canvas.SanitizeData(base(Moonpanel.Canvas.SchemaVersion))
  assert(clean.Sounds.Preset == 'Default', 'panels without sound data did not use Default')
  local custom = base(Moonpanel.Canvas.SchemaVersion)
  custom.Sounds = {Preset = 'CRT'}
  assert(Moonpanel.Canvas.SanitizeData(custom).Sounds.Preset == 'CRT',
    'known sound preset was not retained')
  custom.Sounds.Preset = 'Not a preset'
  assert(Moonpanel.Canvas.SanitizeData(custom).Sounds.Preset == 'Default',
    'unknown sound preset was not normalized to Default')
end)

test.test('sound preset definitions are sparse and resolve independently', function()
  local preset = Moonpanel.Canvas.ResolveSoundPreset('CRT')
  assert(preset.Directory == 'presets/crt', 'CRT sound preset directory was not resolved')
  assert(Moonpanel.Canvas.ResolveSoundPreset('Missing preset') == nil,
    'unknown sound preset did not return nil')
  preset.Directory = 'changed'
  assert(Moonpanel.Canvas.SoundPresets.CRT.Directory == 'presets/crt',
    'resolved sound preset shared mutable definition state')
end)

test.test('symmetry trace color values remain independently configurable', function()
  local data = base(Moonpanel.Canvas.SchemaVersion)
  assert(Moonpanel.Canvas.SanitizeData(data).Meta.SymmetryOptions.Traces[1].ColorValue == nil,
    'missing trace appearance was synthesized')
  data.Meta.SymmetryOptions.Traces[1].ColorValue = {r = 200, g = 201, b = 202, a = 255}
  data.Meta.SymmetryOptions.Traces[2].ColorValue = {r = 12, g = 34, b = 56, a = 200}
  data.Meta.SymmetryOptions.Traces[2].Invisible = true
  local clean = Moonpanel.Canvas.SanitizeData(data)
  local secondary = clean.Meta.SymmetryOptions.Traces[2].ColorValue
  assert(secondary.r == 12 and secondary.g == 34 and secondary.b == 56 and secondary.a == 200,
    'secondary trace appearance was not preserved independently')
  assert(clean.Meta.SymmetryOptions.Traces[1].ColorValue.r ~= secondary.r or
    clean.Meta.SymmetryOptions.Traces[1].ColorValue.g ~= secondary.g,
    'primary and secondary trace appearances share state')
  assert(clean.Meta.SymmetryOptions.Traces[2].Invisible == true,
    'per-trace invisibility was not preserved')
end)

test.test('The Windmill data imports into canonical panel coordinates', function()
  local entities = {}
  for index = 1, 9 do entities[index] = {} end
  entities[1] = {type = 6, color = Moonpanel.Color.Red}
  entities[5] = {
    type = 9,
    shape = {
      width = 2,
      grid = {1, 0, 0, 1},
      free = true,
    },
  }

  local imported, reason = Moonpanel.Canvas.WindmillToCanvasData({
    contents = {width = 3, entity = entities},
  })
  assert(imported, reason or 'Windmill data was not imported')
  assert(imported.Meta.Width == 1 and imported.Meta.Height == 1,
    'Windmill dimensions were not converted')
  assert(imported.Entities[1].Type == 'Hexagon' and
    imported.Entities[1].Data.RuleColor == Moonpanel.Color.White,
    'Windmill intersection clue was not mapped with its historical tint')
  assert(imported.Entities[5].Type == 'Polyomino' and
    imported.Entities[5].Data.Rotational == true and
    imported.Entities[5].Data.Shape[2][2] == 1,
    'rotatable Windmill polyomino was not mapped')
  assert(imported.Colors.Background.r == 112 and imported.Colors.Errored.r == 220,
    'Windmill appearance preset was not applied')
end)

test.test('The Windmill importer rejects negative polyominoes', function()
  local imported, reason = Moonpanel.Canvas.WindmillToCanvasData({
    contents = {
      width = 3,
      entity = {
        {}, {}, {}, {},
        {type = 9, shape = {width = 1, grid = {1}, negative = true}},
        {}, {}, {}, {},
      },
    },
  })
  assert(imported == nil and reason and reason:find('Negative polyominoes'),
    'negative Windmill polyomino was not rejected')
end)

test.test('schema migration infers legacy colorful dot roles once', function()
  local data = base(1)
  data.Meta.Symmetry = Moonpanel.Canvas.Symmetry.Vertical
  data.Meta.SymmetryOptions.Colorful = true
  local dot = flatIndex(1, 1, 1)
  data.Entities[dot] = {
    Type = 'Hexagon',
    Data = {Color = Moonpanel.Color.Magenta},
  }
  local migrated = Moonpanel.Canvas.SanitizeData(data)
  assert(migrated.SchemaVersion == Moonpanel.Canvas.SchemaVersion,
    'schema version was not advanced')
  assert(migrated.Entities[dot].Data.TraceRole == Moonpanel.Canvas.DotRole.Secondary,
    'legacy branch tint was not compiled to a semantic role')
end)

test.test('continuous topology is a canonical panel parameter', function()
  local data = base(Moonpanel.Canvas.SchemaVersion)
  data.Meta.Continuous = true
  local clean = Moonpanel.Canvas.SanitizeData(data)
  assert(clean.Meta.Continuous == true, 'continuous topology was not serialized')
  data.Meta.Continuous = nil
  assert(Moonpanel.Canvas.SanitizeData(data).Meta.Continuous == false,
    'bounded topology was not the migration default')
end)

test.test('legacy grid conversion retains colorful dot inference context', function()
  local converted = Moonpanel.Canvas.SanitizeData({
    Tile = {Width = 1, Height = 1},
    Symmetry = {
      Type = Moonpanel.Canvas.Symmetry.Vertical,
      Colorful = true,
      Traces = {
        {Color = Moonpanel.Color.Cyan},
        {Color = Moonpanel.Color.Magenta},
      },
    },
    Intersections = {
      {
        {Type = 3, Attributes = {Color = Moonpanel.Color.Magenta}},
        {},
      },
      {{}, {}},
    },
  })
  local dot = flatIndex(1, 1, 1)
  assert(converted.Entities[dot].Data.TraceRole == Moonpanel.Canvas.DotRole.Secondary,
    'legacy grid conversion erased branch-color evidence too early')
end)

test.test('legacy Tile colorful symmetry recovers branch and hexagon colors', function()
  local converted = Moonpanel.Canvas.SanitizeData({
    Tile = {
      Width = 3,
      Height = 3,
      Symmetry = 1,
      ColorfulSymmetry = true,
    },
    VPaths = {
      {},
      {
        [2] = {Type = 3, Attributes = {Color = Moonpanel.Color.Magenta}},
        [3] = {Type = 3, Attributes = {Color = Moonpanel.Color.Cyan}},
      },
    },
  })
  local traces = converted.Meta.SymmetryOptions.Traces
  local primary = flatIndex(3, 3, 4)
  local secondary = flatIndex(3, 5, 4)

  assert(converted.Meta.SymmetryOptions.Colorful == true,
    'legacy Tile.ColorfulSymmetry was not retained')
  assert(traces[1].RuleColor == Moonpanel.Color.Magenta and
    traces[2].RuleColor == Moonpanel.Color.Cyan,
    'legacy hexagon colors were not recovered as branch colors')
  assert(traces[1].ColorValue == nil and traces[2].ColorValue == nil,
    'legacy rule colors were redundantly imported as appearance overrides')
  assert(converted.Entities[primary].Data.TraceRole == Moonpanel.Canvas.DotRole.Primary and
    converted.Entities[secondary].Data.TraceRole == Moonpanel.Canvas.DotRole.Secondary,
    'legacy colored hexagons were not assigned to their recovered branches')
end)

test.test('legacy Tile symmetry migrates rotational panels', function()
  local converted = Moonpanel.Canvas.SanitizeData({
    Tile = {Width = 3, Height = 3, Symmetry = 1},
    Intersections = {
      {[1] = {Type = 1}, [4] = {Type = 2}},
      {},
      {},
      {[1] = {Type = 2}, [4] = {Type = 1}},
    },
  })
  assert(converted.Meta.Symmetry == Moonpanel.Canvas.Symmetry.Rotational,
    'legacy Tile.Symmetry=1 was not migrated to rotational symmetry')
end)

test.test('legacy Tile symmetry preserves directional branches', function()
  local vertical = Moonpanel.Canvas.SanitizeData({
    Tile = {Width = 3, Height = 3, Symmetry = 2},
  })
  local horizontal = Moonpanel.Canvas.SanitizeData({
    Tile = {Width = 3, Height = 3, Symmetry = 3},
  })
  assert(vertical.Meta.Symmetry == Moonpanel.Canvas.Symmetry.Horizontal,
    'legacy Tile.Symmetry=2 was not migrated to horizontal symmetry')
  assert(horizontal.Meta.Symmetry == Moonpanel.Canvas.Symmetry.Vertical,
    'legacy Tile.Symmetry=3 was not migrated to vertical symmetry')
end)

test.test('current dot roles remain independent from tint', function()
  local data = base(Moonpanel.Canvas.SchemaVersion)
  local dot = flatIndex(1, 1, 1)
  data.Entities[dot] = {
    Type = 'Hexagon',
    Data = {
      TintColor = Moonpanel.Color.Magenta,
      RuleColor = Moonpanel.Color.Green,
      TraceRole = Moonpanel.Canvas.DotRole.Any,
    },
  }
  local clean = Moonpanel.Canvas.SanitizeData(data)
  assert(clean.Entities[dot].Data.TraceRole == Moonpanel.Canvas.DotRole.Any,
    'explicit neutral role was overwritten by its tint')
  assert(clean.Entities[dot].Data.RuleColor == Moonpanel.Color.Green,
    'semantic color was collapsed into display tint')
  assert(clean.Entities[dot].Data.TintColor == Moonpanel.Color.Magenta,
    'distinct canonical tint was discarded')
  assert(clean.Entities[dot].Data.Color == nil,
    'ambiguous legacy Color survived canonical sanitization')
end)

test.test('schema v2 repairs palette-authored semantic color mismatches', function()
  local data = base(2)
  local white = flatIndex(1, 2, 2)
  data.Entities[white] = {
    Type = 'Color',
    Data = {
      Color = Moonpanel.Color.White,
      RuleColor = Moonpanel.Color.Black,
    },
  }

  local migrated = Moonpanel.Canvas.SanitizeData(data)
  assert(migrated.SchemaVersion == Moonpanel.Canvas.SchemaVersion, 'v2 panel was not migrated')
  assert(migrated.Entities[white].Data.RuleColor == Moonpanel.Color.White,
    'v2 stale rule identity did not follow the authored visible color')
  assert(migrated.Entities[white].Data.TintColor == nil,
    'redundant migrated tint was retained')
  assert(migrated.Entities[white].Data.Color == nil,
    'ambiguous migrated Color was retained')

end)

test.test('custom tint persists only while distinct from rule color', function()
  local data = base(3)
  local cell = flatIndex(1, 2, 2)
  data.Entities[cell] = {
    Type = 'Color',
    Data = {
      Color = Moonpanel.Color.Magenta,
      RuleColor = Moonpanel.Color.Green,
    },
  }

  local migrated = Moonpanel.Canvas.SanitizeData(data)
  local clue = migrated.Entities[cell].Data
  assert(clue.RuleColor == Moonpanel.Color.Green and
    clue.TintColor == Moonpanel.Color.Magenta,
    'schema v3 custom tint was not canonized')
  assert(clue.Color == nil, 'schema v3 Color alias survived migration')

  clue.TintColor = clue.RuleColor
  local current = Moonpanel.Canvas.SanitizeData(migrated)
  assert(current.Entities[cell].Data.TintColor == nil,
    'tint equal to rule color was serialized redundantly')
end)

test.test('legacy hollow dots become canonical invisible dots', function()
  local data = base(5)
  local dot = flatIndex(1, 1, 1)
  data.Entities[dot] = {
    Type = 'Hexagon',
    Data = {
      RuleColor = Moonpanel.Color.Cyan,
      TraceRole = Moonpanel.Canvas.DotRole.Any,
      Hollow = true,
      Negative = true,
    },
  }
  data.Extensions = {HollowDot = true}

  local migrated = Moonpanel.Canvas.SanitizeData(data)
  local clue = migrated.Entities[dot].Data
  assert(clue.Invisible == true and clue.Negative == true,
    'dot visibility and polarity were not migrated independently')
  assert(clue.Hollow == nil, 'ambiguous hollow dot field survived migration')
  assert(migrated.Extensions.InvisibleDot and migrated.Extensions.NegativeDot,
    'dot extension flags do not describe canonical behavior')
  assert(migrated.Extensions.HollowDot == nil,
    'obsolete hollow-dot extension survived migration')
end)

test.test('empty and padded polyomino shapes are canonicalized', function()
  local data = base(2)
  local cell = flatIndex(1, 2, 2)
  data.Entities[cell] = {
    Type = 'Polyomino',
    Data = {Shape = {{0, 0}, {0, 0}}, Negative = true},
  }
  local empty = Moonpanel.Canvas.SanitizeData(data)
  assert(empty.Entities[cell].Data.Shape[1][1] == 1,
    'empty shape survived sanitization')
  assert(empty.Entities[cell].Data.Negative == true,
    'negative sign was lost')

  data.Entities[cell].Data.Shape = {{0, 0, 0}, {0, 1, 0}, {0, 0, 0}}
  local trimmed = Moonpanel.Canvas.SanitizeData(data)
  assert(#trimmed.Entities[cell].Data.Shape == 1 and
    #trimmed.Entities[cell].Data.Shape[1] == 1,
    'shape padding was not trimmed deterministically')
end)

test.test('non-Witness constructs are explicit extension flags', function()
  local data = base(2)
  local cell = flatIndex(1, 2, 2)
  local path = flatIndex(1, 2, 1)
  data.Entities[cell] = {
    Type = 'Triangle',
    Data = {Color = Moonpanel.Color.Orange, Count = 4},
  }
  data.Entities[path] = {Type = 'Start'}
  local clean = Moonpanel.Canvas.SanitizeData(data)
  assert(clean.Extensions.FourTriangle and clean.Extensions.MidpointTerminals,
    'extension status did not describe authored non-Witness entities')
end)

test.test('invalid socket assignments are removed before compilation', function()
  local data = base(2)
  local intersection = flatIndex(1, 1, 1)
  data.Entities[intersection] = {
    Type = 'Triangle', Data = {Color = Moonpanel.Color.Orange, Count = 1},
  }
  local clean = Moonpanel.Canvas.SanitizeData(data)
  assert(clean.Entities[intersection].Type == nil,
    'cell clue survived on an intersection')
end)

test.test('grid geometry auto-fits donor defaults across panel sizes', function()
  local expected = {
    [3] = {width = 20, length = 124},
    [4] = {width = 20, length = 92},
    [10] = {width = 8, length = 40},
  }
  for size, values in pairs(expected) do
    local geometry = Moonpanel.Canvas.CalculateGeometry({
      Meta = {Width = size, Height = size},
      Dim = {
        BarWidth = 4,
        BarLength = 25,
        InnerScreenRatio = 0.8,
        AutoBarWidth = true,
      },
    }, 512)
    assert(geometry.barWidth == values.width and geometry.barLength == values.length,
      string.format('%dx%d donor geometry changed', size, size))
    assert(geometry.innerWidth <= 512 * 0.8 and geometry.innerHeight <= 512 * 0.8,
      string.format('%dx%d geometry exceeded its inner screen', size, size))
  end
end)

test.test('authored width and maximum spacing remain bounded inputs', function()
  local geometry = Moonpanel.Canvas.CalculateGeometry({
    Meta = {Width = 4, Height = 2},
    Dim = {
      BarWidth = 3,
      BarLength = 10,
      InnerScreenRatio = 0.8,
      AutoBarWidth = false,
    },
  }, 512)
  assert(geometry.barWidth == 15, 'manual line width was ignored')
  assert(geometry.cellLength == 51 and geometry.barLength == 66,
    'maximum cell size did not cap fitted geometry')
  assert(geometry.innerWidth <= 512 * 0.8, 'manual geometry escaped the inner screen')
end)

test.test('legacy dimensions retain donor-relative fitting semantics', function()
  local converted = Moonpanel.Canvas.SanitizeData({
    Tile = {Width = 3, Height = 3},
    Dimensions = {
      InnerScreenRatio = 0.8,
      BarWidth = 0.05,
      MaxBarLength = 0.25,
    },
  })
  assert(converted.Dim.AutoBarWidth == false, 'authored legacy width became automatic')
  assert(math.abs(converted.Dim.BarWidth - 4) < 0.0001,
    'legacy inner-relative line width was not converted')
  assert(math.abs(converted.Dim.BarLength - 20) < 0.0001,
    'legacy inner-relative spacing cap was not converted')
  assert(converted.Dim.MaxBarLength == nil,
    'obsolete legacy spacing field survived canonical migration')
  local convertedGeometry = Moonpanel.Canvas.CalculateGeometry(converted, 512)
  assert(convertedGeometry.barWidth == 20 and convertedGeometry.cellLength == 102 and
    convertedGeometry.barLength == 122,
    'legacy 3x3 panel did not reproduce its donor fit')

  local defaults = Moonpanel.Canvas.SanitizeData({
    Tile = {Width = 10, Height = 10},
    Dimensions = {},
  })
  assert(defaults.Dim.AutoBarWidth == true,
    'missing legacy width did not retain adaptive donor defaults')
  assert(math.abs(defaults.Dim.DisjointLength - 0.4) < 0.0001,
    'missing legacy gap size did not use the canonical 40% default')
  local sentinel = Moonpanel.Canvas.SanitizeData({
    Tile = {Width = 3, Height = 3},
    Dimensions = {DisjointLength = 1},
  })
  assert(math.abs(sentinel.Dim.DisjointLength - 0.4) < 0.0001,
    'legacy gap sentinel 1 was treated as an enormous literal gap')
  local geometry = Moonpanel.Canvas.CalculateGeometry(defaults, 512)
  assert(geometry.innerWidth <= 512 * 0.8,
    'large legacy panel did not fit after migration')
end)

test.test('canonical panels default gaps to forty percent', function()
  local data = Moonpanel.Canvas.SanitizeData({
    SchemaVersion = Moonpanel.Canvas.SchemaVersion,
    Meta = {Width = 3, Height = 3},
    Dim = {},
    Entities = {},
  })
  assert(math.abs(data.Dim.DisjointLength - 0.4) < 0.0001,
    'canonical missing gap size did not default to 40%')

  data = Moonpanel.Canvas.SanitizeData({
    SchemaVersion = Moonpanel.Canvas.SchemaVersion,
    Meta = {Width = 3, Height = 3},
    Dim = {DisjointLength = 0.25},
    Entities = {},
  })
  assert(math.abs(data.Dim.DisjointLength - 0.25) < 0.0001,
    'explicit authored gap size was overwritten by the default')
end)

test.test('canonical sanitization retains only supported extension flags', function()
  local data = Moonpanel.Canvas.SanitizeData({
    Extensions = { FourTriangle = true, ArbitraryPayload = true },
  })
  assert(data.Extensions.FourTriangle and data.Extensions.ArbitraryPayload == nil,
    'unsupported extension data crossed the Canvas boundary')
end)

test.run()
