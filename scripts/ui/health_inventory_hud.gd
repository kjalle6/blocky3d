extends Control
## Screen-space pixel HUD; quantities and health belong to the player.
const ENEMY_CONTACT := preload("res://scripts/combat/enemy_combat_contact.gd")
const FULL := preload("res://assets/art/ui/health/player_full.png")
const EMPTY := preload("res://assets/art/ui/health/player_empty.png")
const FONT := preload("res://assets/art/ui/health/cyberpunk_pixel.otf")
const INK := Color("#f4f5d2")
## Width at 100 maximum HP; upgrades extend the bar without scaling its height.
@export var bar_width := 120.0
var _session: LevelSession3D
var _targets: Array[Node] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func bind_session(session: LevelSession3D) -> void:
	_session = session
	_targets.clear()
	if is_instance_valid(session):
		for target in get_tree().get_nodes_in_group("melee_target"):
			if session.is_ancestor_of(target):
				_targets.append(target)
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(_session) or not is_instance_valid(_session.player):
		return
	var player := _session.player
	var origin := Vector2(24, 40)
	var health_bar_width := roundf(bar_width * player.health.maximum / 100.0)
	var ratio := float(player.health.current) / player.health.maximum
	draw_texture_rect(EMPTY, Rect2(origin, Vector2(health_bar_width, 32)), false)
	if ratio > 0:
		draw_texture_rect_region(FULL, Rect2(origin, Vector2(health_bar_width * ratio, 32)),
			Rect2(Vector2.ZERO, Vector2(FULL.get_width() * ratio, FULL.get_height())))
	var hp_text := "%d/%d" % [player.health.current, player.health.maximum]
	var hp_text_width := FONT.get_string_size(hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var hp_position := origin + Vector2(
		roundf((health_bar_width - hp_text_width) * 0.5),
		roundf((32.0 - FONT.get_height(18)) * 0.5 + FONT.get_ascent(18)))
	draw_string_outline(FONT, hp_position, hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 4, Color("#101b2b"))
	draw_string(FONT, hp_position, hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, INK)
	for index in 2:
		var pos := origin + Vector2(index * 100, 40)
		draw_rect(Rect2(pos, Vector2(92, 36)), Color("#15213be8"))
		draw_rect(Rect2(pos, Vector2(92, 36)), Color("#658091"), false, 1)
		var item_id := player.inventory.quick_slots[index]
		var item := ItemCatalog.definition(item_id)
		var count := player.inventory.count(item_id)
		if item != null and item.icon != null:
			var color := Color.WHITE if count > 0 else Color(0.45, 0.45, 0.5)
			draw_texture_rect(item.icon, Rect2(pos + Vector2(26, 5), Vector2(26, 26)), false, color)
		draw_string(FONT, pos + Vector2(6, 24), "Q" if index == 0 else "E", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK)
		var count_text := str(count) if count < 1000 else "%.1fk" % (count / 1000.0)
		draw_string(FONT, pos + Vector2(55, 24), count_text, HORIZONTAL_ALIGNMENT_RIGHT, 30, 14, INK)
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	for target in _targets:
		if not is_instance_valid(target) or target.is_defeated() or not target.visible:
			continue
		var hp: HealthState = target.health
		if not hp.has_taken_damage:
			continue
		var bounds := ENEMY_CONTACT.stomp_bounds(target)
		var point := Vector3(bounds.get_center().x, bounds.end.y + 0.28, 0)
		if camera.is_position_behind(point):
			continue
		var screen := camera.unproject_position(point).round() - Vector2(24, 3)
		draw_rect(Rect2(screen, Vector2(48, 6)), Color("#26354b"))
		draw_rect(Rect2(screen, Vector2(roundf(48.0 * hp.current / hp.maximum), 6)), Color("#eb705b"))
	if player.healing_remaining > 0.0 and not player.is_dead():
		var pos := camera.unproject_position(player.global_position + Vector3(0, 1.3, 0)).round()
		draw_rect(Rect2(pos + Vector2(-3, -11), Vector2(6, 22)), Color("#75ecbd"))
		draw_rect(Rect2(pos + Vector2(-11, -3), Vector2(22, 6)), Color("#75ecbd"))
		draw_string(FONT, pos + Vector2(18, 8), "+%d" % player.last_healing_amount,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#b3ffd3"))
