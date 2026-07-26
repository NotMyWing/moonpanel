# WireMod and Expression 2

WireMod is optional. Moonpanel works without it.

## Wire inputs

| Input | Behavior |
| --- | --- |
| `TurnOff` | `1` powers the panel off and resets its active solution; `0` or any other numeric value powers it on. |
| `Reset` | A pulse with value `1` resets runtime and solved state, preserves the panel document, and re-enables the panel. |

## Wire outputs

| Output | Behavior |
| --- | --- |
| `Powered` | Whether the panel is powered. |
| `Solved` | Whether the panel is solved. With erasers, this changes after the eraser feedback finishes. |
| `Errored` | Whether the most recent terminal evaluation reported an error. |
| `Success` | Legacy numeric success output. It follows the historical eraser delay. |
| `SolvedPulse` | One pulse for a successful terminal evaluation. |
| `FailedPulse` | One pulse for an unsuccessful terminal evaluation. |
| `AbortedPulse` | One pulse when an active trace is aborted. |
| `Erased [ARRAY]` | Erased cells in the legacy `Vector(x, y, objectType)` format. |
| `Path [STRING]` | The primary terminal trace as bounded `U`, `D`, `L`, `R`, or `?` direction characters. |

The outputs update when the panel is powered, reset, edited, or finished with
a trace. Wire connections and port settings are restored with duplicators and
saves.

## Expression 2

WireMod loads the optional Moonpanel E2 extension, which provides:

`moonpanelPowered`, `moonpanelSolved`, `moonpanelErrored`, `moonpanelPath`,
`moonpanelRevision`, `moonpanelWidth`, `moonpanelHeight`, `moonpanelCell`,
`moonpanelData`, and owner-checked `moonpanelReset`.

`moonpanelData` is limited to 8192 characters. `moonpanelReset` clears the
current run without changing the puzzle layout.
