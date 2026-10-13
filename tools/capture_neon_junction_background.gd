extends SceneTree
## Opt-in rendered timeline capture for the isolated menu background.
## Run with tools/run_godot_tool.ps1 -Visual -Script res://tools/capture_neon_junction_background.gd
const OUTPUT_SIZE := Vector2i(1280,720)
const FRAME_COUNT := 240
const FRAME_RATE := 24.0
const OUTPUT_DIR := "res://build/neon_junction_capture"

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    if DisplayServer.get_name() == "headless":
        push_error("Neon Junction capture needs rendering; use the runner's -Visual mode.")
        quit(1)
        return
    root.content_scale_size = OUTPUT_SIZE
    root.size = OUTPUT_SIZE
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
    var packed := load("res://scenes/dev/neon_junction_background_preview.tscn") as PackedScene
    assert(packed != null, "The preview scene must load.")
    var preview := packed.instantiate()
    root.add_child(preview)
    preview.set_process(false)
    for frame in 4:
        await process_frame
    var output := ProjectSettings.globalize_path(OUTPUT_DIR)
    assert(DirAccess.make_dir_recursive_absolute(output) == OK)
    for frame in FRAME_COUNT:
        preview.set_preview_time(float(frame) / FRAME_RATE)
        await process_frame
        await RenderingServer.frame_post_draw
        var capture := root.get_texture().get_image()
        assert(capture.get_size() == OUTPUT_SIZE, "Unexpected capture dimensions.")
        var error := capture.save_png(output.path_join("frame_%04d.png" % frame))
        assert(error == OK, "Failed to save a capture frame.")
    print("NEON_JUNCTION_CAPTURE PASS: %d deterministic frames at %s" % [FRAME_COUNT,output])
    quit(0)
