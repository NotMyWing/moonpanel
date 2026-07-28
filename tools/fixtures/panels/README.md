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
`erasureCount`, `eraserTargetCount`, `nonEraserTargetCount`, `remaining`,
`remainingCount`, `constraintKinds`, `polyominoBackends`, `reportHash`, and
`ruleRevision`.
`polyominoBackends` lists the placement backend for each region that contains
an accepted polyomino witness. Add only stable semantic fields; presentation
state does not belong in a panel fixture.

`allSimpleTraces` exhaustively enumerates simple paths between `from` and `to`.
Its optional `count` asserts the number of geometric routes. Its optional
`solutions` evaluates every route, asserts the number that solve the panel,
and applies the test's `expected` fields to the successful report.
