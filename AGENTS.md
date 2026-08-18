# Godot automation safety

This Windows machine has repeatedly produced native Godot 4.6.3 access-
violation dialogs during automation. Earlier Mono incidents faulted in
CoreCLR; the standard non-.NET build has also faulted during later automation.
The shared root cause is not yet proven. The project contains no C# code, so
automation still uses the smaller standard build through Compatibility.

- Never launch either Godot executable directly for validation or captures.
- Always use `tools/run_godot_tool.ps1`.
- Keep the runner on the standard non-.NET executable; do not override it with
  the Mono build.
- `--headless` is opt-in through the runner's `-Headless` switch and is never
  the default. It was an early repeatable trigger for the native access
  violations and the root cause was never proven, so it is kept available
  deliberately rather than trusted: if native faults reappear, drop `-Headless`
  first and see whether they stop. Headless runs are labelled `script_headless`
  in the log filename so they can be told apart afterwards. It cannot be
  combined with `-Visual`, `-Game`, or `-EditorImport`.
- Headless removes the window, not the work. Measured across the full suite it
  saves about 25 seconds; the long validators are simulation-bound, not
  render-bound. It is not a speed fix.
- Choose windowed or headless per run, by what that run needs to tell you. A
  visible run the user can watch and screenshot answers questions about feel,
  composition, and readability that an exit code cannot, and is worth more than
  several invisible ones. Headless suits contract questions and long scoped
  sweeps. Neither is the default worth defending; the run's purpose decides.
- Preserve running Godot editor/game processes by default. `--headless` was an
  early repeatable trigger, but neither it nor concurrent processes is accepted
  as the sole root cause without a crash dump.
- The user has explicitly authorized closing Godot without pausing to ask when
  exclusive access is genuinely needed. In that case pass `-CloseRunningGodot`;
  it closes only processes whose names begin with `Godot`, gracefully first and
  then forcibly if necessary.
- Never bypass the runner with a direct Godot command.
- Use the runner's `-Visual` switch for graphical capture scripts so they get
  an explicit review resolution. Validators still use the normal renderer.
- After renaming a `class_name` script or its file, refresh Godot's generated
  class cache with the runner's `-EditorImport` switch before validation. Add
  `-CloseRunningGodot` when an open editor still holds the old class registry.
- `-EditorImport` must continue to use Godot's dedicated `--import` mode. Never
  implement it as `--editor --quit`; that exits on the first iteration while
  import workers may still be active and emitted unfinished-thread warnings in
  the same sessions as native access violations.
- The runner fails any `-Script` run whose log contains `SCRIPT ERROR`, even
  when Godot itself exits 0. A failed `assert()` aborts only the function it
  occurs in; the caller keeps running and can still reach `quit(0)`, so without
  this check a validator can print its success message and exit cleanly while an
  assertion inside a helper has failed.
- Keep every runner mode supervising the real non-console Godot executable
  with `Start-Process -Wait`; the Windows console launcher alone cannot be
  trusted to surface a delayed process crash. Keep the runner's exclusive
  automation lock so two tool instances cannot overlap.
- The complete source-art catalog under `assets/library` is intentionally
  visible to Godot for searching and auditioning. Promote selected production
  assets into `assets/art`; do not mistake catalog availability for permission
  to make every pack a runtime dependency. Asset import volume is not accepted
  as the root cause of the unresolved native automation crash.

Canonical examples:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run_validation_suite.ps1
powershell -ExecutionPolicy Bypass -File .\tools\run_validation_suite.ps1 -Scope All -Headless
powershell -ExecutionPolicy Bypass -File .\tools\run_godot_tool.ps1 -Script res://tools/validate_project.gd
powershell -ExecutionPolicy Bypass -File .\tools\run_godot_tool.ps1 -Visual -Script res://tools/capture_arrival_shoreline_slice.gd
powershell -ExecutionPolicy Bypass -File .\tools\run_godot_tool.ps1 -EditorImport -CloseRunningGodot
```

## Running the validators

Use `tools/run_validation_suite.ps1` rather than looping over `validate_*.gd`
by hand. A loop over the directory can only mean every validator, and a full
pass is dominated by the twelve `level1-6` validators guarding the frozen
prototypes - about 60% of the wall time, and unaffected by most changes.

- `-Scope Current` (default, ~78s headless): everything except those twelve.
- `-Scope Prototype` (~132s headless): only the frozen fixtures.
- `-Scope All`: both. Run before a commit, and after any change to shared
  infrastructure - the runner, `GameRoot`, or `pixel_level_base.tscn` - because
  those can change the result of validators that look unrelated.

Run the suite when a change could plausibly reach what it covers, not as
reassurance. Two full passes in a row, the second confirming what the first
already proved, is wasted time whether or not it opens windows.
