extends "res://scripts/ui/neon_junction_background.gd"

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_SPACE:
            motion_enabled = not motion_enabled
            get_viewport().set_input_as_handled()
        elif event.keycode == KEY_B:
            set_night_sky_enabled(not night_sky_enabled)
            get_viewport().set_input_as_handled()
        elif event.keycode == KEY_S:
            set_smoke_motion_enabled(not smoke_motion_enabled)
            get_viewport().set_input_as_handled()
        elif event.keycode == KEY_H:
            _help.visible = not _help.visible
            get_viewport().set_input_as_handled()
        elif event.keycode == KEY_ESCAPE:
            get_tree().quit()
