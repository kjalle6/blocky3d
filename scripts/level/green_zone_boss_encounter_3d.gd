extends Node
## Runs the Green Zone boss pit: the entry cutscene, the boss's health bar, and
## the way out. The pit opens off the end of Level 3's upper plateau. On arrival
## the cutscene walks the player to the lip, looks down into the pit, and drops
## them onto the wall below. As they slide, the camera swings right and down to
## S.T.O.M.P. turning to aim its missiles at them. With its pod raised, the game
## freezes for a reveal of its name; then the boss bar fills, the camera comes
## quickly back, control returns near the bottom, still sliding, and the boss
## fires that salvo. The cutscene plays on every arrival, and a fresh press
## skips it. A death sends the run back to the plateau checkpoint before the
## pit. Manual saves wait for the boss to die, and its death autosaves; the
## kill, the warhead and the open door are kept with the run. Destroying the
## boss drops its warhead; carried to the exit door, it blows the door open,
## and the doorway ends the level.

signal intro_started
signal intro_finished
signal warhead_dropped(pickup: Node3D)
signal warhead_collected
signal exit_opened

enum Phase { ARRIVE, LOOK, DROP, SLIDE, FIGHT }

const WARHEAD := preload("res://scripts/pickups/boss_warhead_pickup_3d.gd")
const HEALTH_BAR := preload("res://scripts/ui/boss_health_bar.gd")
const REVEAL := preload("res://scripts/ui/boss_reveal.gd")
## The fight's outcome, kept with the run and its saves, so a load or a
## return after the kill finds the boss dead and the way out where it was.
const BOSS_DEFEATED_FLAG := "green_zone_boss_pit/boss_defeated"
const WARHEAD_TAKEN_FLAG := "green_zone_boss_pit/warhead_taken"
const EXIT_OPEN_FLAG := "green_zone_boss_pit/exit_open"
const SAVE_BLOCKED := "You can't save during a boss fight."
const PLAYER_HALF_WIDTH := 0.36
## Seconds the defeated boss's bar stays up before it clears.
const DEFEATED_BAR_TIME := 2.5
## How far from the wreck's centre the warhead lands; past the boss's body.
const WARHEAD_CLEARANCE := 2.4

@export var boss_path := NodePath("../GreenZoneBoss")
@export var exit_door_path := NodePath("../Props/ExitDoor")
@export var exit_goal_path := NodePath("../ExitGoal")
## Off for test rooms that reuse the pit: the fight is live from the start.
@export var intro_enabled := true
@export var health_bar_enabled := true
@export_category("Entry beat")
## The pit wall under the plateau's lip, and the lip's height.
@export var entry_wall_x := 0.0
@export var entry_lip_y := 38.4
## Seconds standing still on arrival, under the end of the fade.
@export_range(0.0, 2.0, 0.05) var arrival_hold := 0.5
@export_range(1.0, 10.0, 0.1) var approach_speed := 5.0
## Seconds the camera takes to dip into the pit; the player hops off as it
## arrives, with no hold.
@export_range(0.2, 3.0, 0.05) var look_down_time := 0.6
## How far the camera dips below the player to look into the pit.
@export_range(0.0, 10.0, 0.1) var look_down_depth := 6.0
@export_range(0.1, 1.0, 0.01) var drop_time := 0.22
## Seconds after the hop off the lip before the camera swings to the boss.
@export_range(0.0, 2.0, 0.05) var slide_lead_time := 0.0
@export_range(0.2, 2.0, 0.05) var pan_time := 0.7
@export_range(0.3, 3.0, 0.05) var boss_hold_time := 1.3
@export_range(0.2, 2.0, 0.05) var pan_back_time := 0.45
@export_range(0.0, 1.0, 0.05) var settle_time := 0.2
## Feet height at which control returns, still sliding. The scripted slide
## speeds up while the camera is on the boss, so it arrives here on time.
@export var release_feet_y := 5.12
@export_range(6.0, 14.0, 0.1) var boss_shot_size := 11.5
## Centre of the boss shot from the boss's feet: room ahead of its turn toward
## the player, and its feet clear of the bottom edge.
@export var boss_shot_center := Vector2(-3.2, 3.9)
## Seconds after control returns before the boss fires the salvo it readied.
@export_range(0.0, 2.0, 0.05) var opening_salvo_delay := 0.25
## Freeze-frame reveal of the boss's name once its pod is raised. The boss bar
## fills as the reveal lets go.
@export var reveal_enabled := true
@export_range(0.0, 2.0, 0.05) var reveal_after_notice := 0.65
## Seconds the reveal holds unless the player presses on after its first moment.
@export_range(0.5, 10.0, 0.05) var reveal_hold := 2.4
@export_range(8.0, 60.0, 1.0) var cinematic_follow_response := 30.0

@onready var session := get_parent() as LevelSession3D
@onready var boss := get_node(boss_path)
@onready var exit_door := get_node_or_null(exit_door_path)
@onready var exit_goal := get_node_or_null(exit_goal_path) as LevelGoal3D

var phase := Phase.FIGHT
var carrying_warhead := false
var _phase_time := 0.0
var _taken := false
var _noticed := false
var _notice_time := 0.0
var _revealed := false
var _reveal
var _salvo_pending := false
var _drop_from := Vector3.ZERO
var _slide_total := 0.0
## Seconds since the camera's swing to the boss began, from the hop off the lip.
var _swing := 0.0
var _slide_boost := 0.0
var _health_bar
var _bar_generation := 0
var _camera_anchor: Marker3D
var _camera_override := false
var _saved_camera_target: Node3D
var _saved_camera_size := 0.0
var _saved_camera_floor := 0.0
var _saved_follow := Vector2.ZERO
## A skipped cutscene hands over a frame later, so the skip press is not also
## read as the player's first jump.
var _release_pending := false


func _ready() -> void:
	if preload("res://scripts/developer/level_layout_preview.gd").is_preview(self):
		set_physics_process(false)
		return
	add_to_group("run_resettable")
	add_to_group("save_blocker")
	_camera_anchor = Marker3D.new()
	_camera_anchor.name = "CutsceneAnchor"
	add_child(_camera_anchor)
	boss.defeated.connect(_on_boss_defeated)
	if exit_door != null:
		exit_door.opened.connect(_on_exit_opened)
	if exit_goal != null:
		# The doorway's art is the occluder: the player steps into it and is gone.
		exit_goal.reached.connect(func(body: PlayerCharacter) -> void: body.disappear_for_transition())
	if health_bar_enabled:
		var layer := CanvasLayer.new()
		layer.name = "BossPitInterface"
		layer.layer = 5
		add_child(layer)
		_health_bar = HEALTH_BAR.new()
		layer.add_child(_health_bar)
		_health_bar.dock_bottom()
		_health_bar.bind(boss)
		_health_bar.hide()


## The cutscene plays on every arrival until the boss is dead.
func intro_due() -> bool:
	return intro_enabled and not boss_defeated()


func boss_defeated() -> bool:
	return _flag(BOSS_DEFEATED_FLAG)


## Manual saves wait for the boss to die; its death autosaves.
func save_block_reason() -> String:
	return "" if boss_defeated() else SAVE_BLOCKED


func health_bar_visible() -> bool:
	return _health_bar != null and _health_bar.visible


func reveal_active() -> bool:
	return is_instance_valid(_reveal) and _reveal.is_active()


func in_cutscene() -> bool:
	return phase != Phase.FIGHT


func reset_run() -> void:
	_set_camera_override(false)
	carrying_warhead = false
	_phase_time = 0.0
	_taken = false
	_swing = 0.0
	_noticed = false
	_revealed = false
	if is_instance_valid(_reveal):
		_reveal.cancel()
	_reveal = null
	_salvo_pending = false
	_release_pending = false
	_bar_generation += 1
	var due := intro_due()
	phase = Phase.ARRIVE if due else Phase.FIGHT
	boss.end_notice()
	if intro_enabled:
		boss.set_enabled(not due)
	_set_room_framing(not due)
	if due:
		# After the boss's own reset: it starts the beat looking away.
		_stage_boss.call_deferred()
	if boss_defeated():
		_restore_aftermath.call_deferred()
	if _health_bar != null:
		_health_bar.visible = not due and not boss_defeated()
		_health_bar.refresh()


func _unhandled_input(event: InputEvent) -> void:
	# A fresh press skips the cutscene; a key held from the plateau does not.
	if not in_cutscene() or not _taken or event.is_echo() or not event.is_pressed():
		return
	if event.is_action_pressed("jump") or event.is_action_pressed("attack") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_skip_intro()


func _physics_process(delta: float) -> void:
	var player := session.player
	if player == null:
		return
	if phase != Phase.FIGHT:
		_phase_time += delta
	match phase:
		Phase.ARRIVE:
			_tick_arrive(player, delta)
		Phase.LOOK:
			# The dip keeps speeding up to its end, so the swing that follows
			# picks up a moving camera instead of a stopped one.
			_frame(player, look_down_depth * _ease_in(_phase_time / look_down_time), 0.0)
			player.pixel_visual.tick_authored_state(delta, "idle", true)
			if _phase_time >= look_down_time:
				_drop_from = player.global_position
				_swing = -slide_lead_time
				_enter(Phase.DROP)
		Phase.DROP:
			_swing += delta
			_tick_drop(player, delta)
		Phase.SLIDE:
			_swing += delta
			_tick_slide(player, delta)
		Phase.FIGHT:
			if _release_pending:
				_release_pending = false
				_release_player(player)
			_tick_opening_salvo(player, delta)
			_tick_exit(player)


## The cutscene takes the player as the pit appears and walks them to the brink.
func _tick_arrive(player: PlayerCharacter, delta: float) -> void:
	if not _taken and boss_defeated():
		# A return after the kill carries the flag in after the section's own
		# reset armed the cutscene: there is no fight left to introduce.
		_enter(Phase.FIGHT)
		_set_room_framing(true)
		if _health_bar != null:
			_health_bar.hide()
		_restore_aftermath()
		return
	if not _taken:
		_taken = true
		player.stop_for_completion()
		player.global_position.y = entry_lip_y + PlayerCharacter.FEET_OFFSET_Y
		_set_camera_override(true)
		intro_started.emit()
	_frame(player, 0.0, 0.0)
	if _phase_time < arrival_hold:
		player.pixel_visual.tick_authored_state(delta, "idle", true)
		return
	# Toes just over the edge, looking down into the pit.
	var brink := entry_wall_x - 0.2
	player.global_position.x = move_toward(player.global_position.x, brink, approach_speed * delta)
	player.pixel_visual.tick_authored_state(delta, "run", true)
	if is_equal_approx(player.global_position.x, brink):
		player.pixel_visual.tick_authored_state(0.0, "idle", true)
		_enter(Phase.LOOK)


## Off the lip and onto the wall below it, turning to face it.
func _tick_drop(player: PlayerCharacter, delta: float) -> void:
	var t := clampf(_phase_time / drop_time, 0.0, 1.0)
	player.global_position = Vector3(lerpf(_drop_from.x, _wall_x(), _smooth(t)),
		_drop_from.y - 0.6 * t * t, 0)
	player.pixel_visual.tick_authored_state(delta, "jump", true, -6.0)
	# The swing to the boss is already under way during the hop.
	_tick_boss_beat(player)
	_frame(player, look_down_depth, _swing_away())
	if t >= 1.0:
		_begin_slide(player)


func _begin_slide(player: PlayerCharacter) -> void:
	_enter(Phase.SLIDE)
	_slide_total = maxf(0.05, _swing_end() - _swing)
	# A sine bump on top of the ordinary slide speed: it peaks while the camera
	# is on the boss, and starts and ends at the speed the player slides at.
	var base: float = player.movement.wall_slide_max_fall_speed
	var distance := maxf(0.0, player.feet_world_y() - release_feet_y)
	_slide_boost = maxf(0.0, (distance - base * _slide_total) * PI / (2.0 * _slide_total))


func _tick_slide(player: PlayerCharacter, delta: float) -> void:
	var t := _phase_time
	var base: float = player.movement.wall_slide_max_fall_speed
	var step := (base + _slide_boost * sin(PI * clampf(t / _slide_total, 0.0, 1.0))) * delta
	player.global_position.y -= step
	player.pixel_visual.tick_authored_state(delta, "wall_slide", false)
	_tick_boss_beat(player)
	# The look-down holds until the swing comes back, so the camera only ever
	# travels down toward the boss; the swing back lands on the player's
	# ordinary framing.
	_frame(player, look_down_depth if _swing <= _back_start() else 0.0, _swing_away())
	if _swing >= _swing_end() or _landing_within(player, step * 2.0):
		_finish_intro(player)


## On the boss: it notices the player, and once its pod is up, the reveal.
func _tick_boss_beat(player: PlayerCharacter) -> void:
	if not _noticed and _swing >= pan_time * 0.6:
		_noticed = true
		_notice_time = _swing
		boss.begin_notice(player.global_position.x)
		if not reveal_enabled:
			_show_health_bar()
	if reveal_enabled and _noticed and not _revealed and _swing >= _notice_time + reveal_after_notice:
		_revealed = true
		_reveal = REVEAL.new()
		_reveal.hold_time = reveal_hold
		add_child(_reveal)
		_reveal.finished.connect(_show_health_bar)
		_reveal.play(boss.visual, boss.display_name)


func _back_start() -> float:
	return pan_time + boss_hold_time


func _swing_end() -> float:
	return _back_start() + pan_back_time + settle_time


## How far the camera has swung from the player to the boss: out at speed,
## held on the boss, then quickly back.
func _swing_away() -> float:
	if _swing <= _back_start():
		return _ease_out(_swing / pan_time)
	return 1.0 - _smooth((_swing - _back_start()) / pan_back_time)


func _finish_intro(player: PlayerCharacter) -> void:
	_enter(Phase.FIGHT)
	_release_player(player)
	_set_camera_override(false, false)
	# The camera has found the player; now it eases out to hold the boss too.
	_set_room_framing(true)
	_salvo_pending = true
	intro_finished.emit()


## Jumps to where the cutscene ends: the player low on the wall, still
## sliding, the camera on them, the bar filling, the salvo about to fly.
func _skip_intro() -> void:
	if is_instance_valid(_reveal):
		_reveal.cancel()
	_reveal = null
	_noticed = true
	_revealed = true
	var player := session.player
	player.global_position = Vector3(_wall_x(), release_feet_y + PlayerCharacter.FEET_OFFSET_Y, 0)
	player.pixel_visual.tick_authored_state(0.0, "wall_slide", false)
	boss.end_notice()
	boss.face_toward(player.global_position.x)
	_set_camera_override(false)
	_set_room_framing(true)
	session.camera.snap_to_target()
	if session.background != null:
		session.background.snap_to_camera()
	_show_health_bar()
	_salvo_pending = true
	_release_pending = true
	_enter(Phase.FIGHT)
	intro_finished.emit()


func _release_player(player: PlayerCharacter) -> void:
	player.set_physics_process(true)
	player.velocity = Vector3(0, -player.movement.wall_slide_max_fall_speed, 0)


## The boss holds its aim until it fires the salvo the beat showed it readying.
func _tick_opening_salvo(player: PlayerCharacter, delta: float) -> void:
	if not _salvo_pending:
		return
	_phase_time += delta
	if _phase_time < opening_salvo_delay:
		return
	_salvo_pending = false
	boss.end_notice()
	boss.set_enabled(true)
	boss.start_opening_salvo(player)


func _tick_exit(player: PlayerCharacter) -> void:
	if carrying_warhead and exit_door != null and exit_door.is_sealed() \
			and exit_door.overlaps_body(player) and exit_door.arm():
		carrying_warhead = false


## After the kill, from the run's flags: the wreck, and the warhead where
## it lies, in the player's hands, or already spent on the open door.
func _restore_aftermath() -> void:
	boss.restore_defeat()
	if _flag(EXIT_OPEN_FLAG):
		if exit_door != null:
			exit_door.open_instantly()
	elif _flag(WARHEAD_TAKEN_FLAG):
		carrying_warhead = true
	else:
		_drop_warhead(boss.global_position)


func _flag(id: String) -> bool:
	return session.save_state != null and session.save_state.world_flags.get(id, false)


func _show_health_bar() -> void:
	if _health_bar != null:
		_health_bar.show()
		_health_bar.fill()


func _enter(next: Phase) -> void:
	phase = next
	_phase_time = 0.0


func _wall_x() -> float:
	return entry_wall_x + PLAYER_HALF_WIDTH + 0.02


## The scripted slide moves the body directly, so it hands over before it could
## sink into anything below.
func _landing_within(player: PlayerCharacter, distance: float) -> bool:
	var feet := Vector3(player.global_position.x, player.feet_world_y(), 0)
	var query := PhysicsRayQueryParameters3D.create(feet, feet + Vector3.DOWN * distance, player.collision_mask)
	query.exclude = [player.get_rid()]
	return not session.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Blends the cutscene camera between the player, dipped by look, and the boss.
func _frame(player: PlayerCharacter, look: float, away: float) -> void:
	var camera = session.camera
	var near := player.global_position + Vector3.DOWN * look
	# Start from where the camera can actually be, so a swing moves sideways
	# from its first frame instead of waiting to clear the arena's edge.
	near.x = clampf(near.x, camera.minimum_center_x, camera.maximum_center_x)
	# The follow camera centres target_height above its vertical offset.
	var offset_y: float = boss.global_position.y + boss_shot_center.y - camera.target_height
	var far := Vector3(boss.global_position.x + boss_shot_center.x, camera.vertical_anchor_y + offset_y, 0)
	_camera_anchor.global_position = Vector3(near.x, near.y, 0).lerp(far, away)
	camera.size = lerpf(_saved_camera_size, boss_shot_size, away)


func _smooth(value: float) -> float:
	return smoothstep(0.0, 1.0, clampf(value, 0.0, 1.0))


func _ease_in(value: float) -> float:
	var progress := clampf(value, 0.0, 1.0)
	return progress * progress


func _ease_out(value: float) -> float:
	var remaining := 1.0 - clampf(value, 0.0, 1.0)
	return 1.0 - remaining * remaining


## Until control returns the cutscene frames its own shots; afterwards the
## arena camera holds the player and the boss together.
func _set_room_framing(enabled: bool) -> void:
	var camera = session.camera
	if not "encounter_target" in camera:
		return
	camera.encounter_target = boss if enabled else null


func _stage_boss() -> void:
	if phase == Phase.ARRIVE:
		boss.face_toward(boss.global_position.x + 10.0)


## The cutscene drives its own anchor with a tight follow. Handing back keeps
## the current zoom, so the arena camera eases out from it; a cancelled beat
## restores the zoom it interrupted.
func _set_camera_override(enabled: bool, restore_size := true) -> void:
	var camera = session.camera
	if camera == null or _camera_override == enabled:
		return
	_camera_override = enabled
	camera.cinematic_override_enabled = enabled
	if enabled:
		_saved_camera_target = camera.target
		_saved_camera_size = camera.size
		_saved_camera_floor = camera.minimum_vertical_offset
		_saved_follow = Vector2(camera.follow_response, camera.vertical_follow_response)
		camera.follow_response = cinematic_follow_response
		camera.vertical_follow_response = cinematic_follow_response
		# Let the vertical offset dip below the authored floor for the boss shot.
		camera.minimum_vertical_offset = minf(camera.minimum_vertical_offset,
			boss.global_position.y + boss_shot_center.y - camera.target_height)
		camera.target = _camera_anchor
	else:
		camera.target = _saved_camera_target if is_instance_valid(_saved_camera_target) else session.player
		camera.minimum_vertical_offset = _saved_camera_floor
		camera.follow_response = _saved_follow.x
		camera.vertical_follow_response = _saved_follow.y
		if restore_size:
			camera.size = _saved_camera_size
		_saved_camera_target = null


func _on_boss_defeated(impact: Vector3) -> void:
	session.save_state.mark_world_flag(BOSS_DEFEATED_FLAG)
	# The kill autosaves at the first safe footing, and manual saves return.
	session.save_state.queue_entry()
	_drop_warhead(impact)
	if _health_bar != null:
		_bar_generation += 1
		var generation := _bar_generation
		await get_tree().create_timer(DEFEATED_BAR_TIME, false).timeout
		if generation == _bar_generation:
			_health_bar.hide()


func _drop_warhead(impact: Vector3) -> void:
	# It falls clear of the wreck, on the player's side, so it reads against the
	# ground rather than the boss's body.
	var side := signf(session.player.global_position.x - impact.x)
	var x := clampf(impact.x + (side if side != 0.0 else 1.0) * WARHEAD_CLEARANCE,
		boss.minimum_x, boss.maximum_x)
	var from := Vector3(x, impact.y + 1.5, 0)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 80.0, 1 | 64)
	query.exclude = [boss.get_rid(), session.player.get_rid()]
	var hit := session.get_world_3d().direct_space_state.intersect_ray(query)
	var surface_y: float = hit.position.y if not hit.is_empty() else impact.y
	var pickup = WARHEAD.spawn(session, from, surface_y)
	pickup.collected.connect(_on_warhead_collected)
	warhead_dropped.emit(pickup)


func _on_warhead_collected() -> void:
	carrying_warhead = true
	session.save_state.mark_world_flag(WARHEAD_TAKEN_FLAG)
	warhead_collected.emit()


func _on_exit_opened() -> void:
	session.save_state.mark_world_flag(EXIT_OPEN_FLAG)
	exit_opened.emit()
