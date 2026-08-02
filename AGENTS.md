# Godot automation safety

This Windows machine repeatedly produces native Godot 4.6.3 Mono access-
violation dialogs when project scripts are launched with `--headless`. The
same validators pass through the normal Compatibility renderer.

- Never launch either Godot executable directly for validation or captures.
- Always use `tools/run_godot_tool.ps1`.
- Never pass `--headless`, even for validators.
- Preserve running Godot editor/game processes by default. The crash was proven
  to be caused by `--headless`, not merely by concurrent Godot processes.
- The user has explicitly authorized closing Godot without pausing to ask when
  exclusive access is genuinely needed. In that case pass `-CloseRunningGodot`;
  it closes only processes whose names begin with `Godot`, gracefully first and
  then forcibly if necessary.
- Never bypass the runner with a direct Godot command.
- Use the runner's `-Visual` switch for graphical capture scripts so they get
  an explicit review resolution. Validators still use the normal renderer.

Canonical examples:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run_godot_tool.ps1 -Script res://tools/validate_project.gd
powershell -ExecutionPolicy Bypass -File .\tools\run_godot_tool.ps1 -Visual -Script res://tools/capture_arrival_shoreline_slice.gd
```
