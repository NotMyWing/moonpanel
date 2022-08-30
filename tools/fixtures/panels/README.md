# Saved panel fixtures

Each `*.fixture.json` manifest points at an untouched panel export beside it.
The export uses the same JSON format written to Garry's Mod's
`data/moonpanel` directory. A manifest owns a `tests` array so one panel can be
checked against several accepted and rejected routes without duplicating its
serialized data.

Coordinates in each test's `traces` are zero-based panel intersections:
`[0, 0]` is the top-left corner and `[width, height]` is the bottom-right
corner. A test may contain two traces for a symmetry panel. The fixture runner
constructs the canonical grid topology, evaluates the saved panel with the
shared rule engine, and checks every field present in that test's `expected`.

Supported expected fields are `success`, `status`, `violations`, `erasures`,
`remaining`, `constraintKinds`, `polyominoBackends`, `reportHash`, and
`ruleRevision`.
`polyominoBackends` lists the placement backend for each region that contains
an accepted polyomino witness. Add only stable semantic fields; presentation
state does not belong in a panel fixture.
