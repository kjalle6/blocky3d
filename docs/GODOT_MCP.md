# Godot MCP workflow

## Everyday work

Reuse the open project editor. Use MCP for scene inspection and edits, script
checks, live screenshots, and ordinary playtest start/stop:

- `game_start` with `scene_path: "main"` starts the configured game and waits
  for its runtime connection. Use `if_running: "return"` to reuse a playtest.
- Inspect live state, send bounded input sequences with explicit releases,
  and capture with `runtime_screenshot`. `editor_screenshot` captures the
  editor viewport instead.
- Read `debugger_get_log` after testing or an unexpected game disconnect.
  Use `game_stop` to end a playtest without closing the editor.
- Editor playtests use the normal user profile, just like F5. They can write
  normal campaign saves and saved audio/layout tuning; preserve those choices.

If the editor is closed, open it through:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run_godot_tool.ps1 -Editor
```

This bootstrap keeps a per-run log and waits on the real standard Godot process
so editor exit/crash status is available. It uses the normal Windows profile
and does not acquire the standalone automation lock or probe the isolated
profile. It is not needed for each playtest; MCP uses the editor's game lifecycle.

## Standalone checks

Use `tools/run_godot_tool.ps1` for validators, imports, export/pack probes,
repeatable capture scripts, and standalone `-Game` runs when editor playtesting
is not the right test. Use `tools/run_validation_suite.ps1` for a broad sweep.
After a batch of asset additions or changes, refresh the open editor and wait
for its filesystem scan/imports to finish before launching checks. Read fresh
editor errors after the refresh; an old import error is not evidence that a
file is still missing.

For an interrupted suite or a focused rerun, pass validator basenames with
`-Name`, for example `-Name validate_level_layout,validate_project`. Unknown
names fail before launching Godot. Omitting `-Name` still runs every validator.

For an enemy behavior adjustment, run the relevant combat checks and a short
MCP playtest. The Level 2 escape stress test is an opt-in
`tools/probe_shaft_containment.gd`; it is excluded from the routine suite and
only relevant to changes to the machine shaft or movement escape rules.

The runner retains protections MCP does not replace for these jobs:

- Isolated caches and saves under ignored `build/godot_automation_profile`.
- One standalone run at a time through `build/godot_tool.lock`.
- Real non-console process supervision, exit status, and a log per run.
- Failure on logged `SCRIPT ERROR`, even if Godot exits 0.
- Dedicated `--import` completion and isolated pack-probe working directories.

The editor may stay open while a focused standalone check runs. Avoid concurrent
editor mutations/imports; the lock serializes standalone runs, not editor work.
Use `-CloseRunningGodot` only when exclusive access is actually needed, preserving
unsaved edits first. No additional wrapper around MCP game start/stop is needed.
Native Godot crashes remain an unresolved historical issue, not a proven fix.

## Installation and connection

Addon: NPGameDev Godot MCP Toolkit **1.0.0**, vendored with its license at
`addons/godot_mcp_toolkit`, from the official
[release](https://github.com/NPGameDev/godot-mcp-toolkit/releases/tag/v1.0.0).
Archive SHA256:
`2CB4989204CDEA85EFF3282F8C44E5A8CE874EF5F39B372B498144BC03B382D6`.

Bridge: `@npgamedev/godot-mcp-server@1.0.1`, installed with lifecycle scripts
disabled at `D:\GodotTools\godot-mcp-toolkit\server-1.0.1`.
Project-scoped `.codex/config.toml` uses the existing Node 24 runtime directly;
there is no download on each connection. Paths are machine-specific. Restart
Codex after changing its MCP configuration.

The addon binds localhost and publishes its session-token location in the
normal user's registry. Never commit tokens or registry files. The addon may
show a missing `.mcp.json` notice; Codex uses `.codex/config.toml` instead.
Dismiss the first-run wizard with X or Escape after configuring Codex.

If initial authentication times out, bring Godot forward once and retry. The
addon keeps it responsive after authentication; repeated background queries
passed. The addon currently warns about the 1.0.0/1.0.1 version difference;
tested calls work with that pair, but this does not certify every tool.

Activate only needed groups with `discover_tools`. This Codex session did not
immediately expose newly activated tools; screenshot/LSP smoke checks used a
temporary MCP SDK client against the same installed bridge. Core tools loaded
normally. `execute_code` accepts expressions, not full GDScript bodies or inline
lambdas; prefer dedicated tools and simple scoped property reads.

## Verified behavior

On Godot 4.6.3, editor scene inspection, script checking, LSP diagnostics, and
editor/runtime screenshot capture passed. Existing main-script diagnostics are
two `owner` parameter-shadowing warnings, with no compile errors.

The Firearm Review Lab smoke check opened the lab through the menu, moved the
player, released movement, jumped, landed, and returned to selection. Live state
and screenshots agreed; no runtime errors were reported. MCP-owned main-game
start/readiness/stop also passed, without an F5 handoff.

With the updated launcher, the automation-environment and project validators
passed while the editor stayed open. A held standalone lock rejected a second
run before launch. An intentional temporary assertion probe confirmed that an
engine exit of 0 still becomes runner exit 4. The fixture was removed afterward.
No full gameplay suite or scene-mutation test was needed for this workflow change.
