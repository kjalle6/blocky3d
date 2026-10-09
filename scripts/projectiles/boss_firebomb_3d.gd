extends Sprite3D
## Incendiary canister lobbed by the Green Zone boss. It flies a committed
## ballistic arc toward a fixed point, rises through one-way decks, and bursts
## into a fire patch on the first surface it comes down on. Walls stop its
## sideways travel and ceilings stop its climb; it never homes.

const SHEET := preload("res://assets/art/vfx/boss/firebomb.png")
const BURST := preload("res://assets/art/vfx/boss/explosion.png")
const EFFECT := preload("res://scripts/presentation/boss_pixel_effect_3d.gd")
const PATCH := preload("res://scripts/hazards/boss_fire_patch_3d.gd")
const TERRAIN_MASK := 1
const DECK_LAYER := 64
const LIFETIME := 6.0

var velocity := Vector3.ZERO
var gravity := 32.0
var patch_width := 3.84
var burn_time := 30.0
var damage := 25
var variant := 0
## Decks above this height are passed even while falling, so a canister aimed
## under the scaffolding still reaches its spot. Solid terrain always stops it.
var target_y := -INF
var _elapsed := 0.0
var _passed: Array[RID] = []


## Launches toward target so the canister arrives there after flight_time.
static func launch(parent: Node, origin: Vector3, target: Vector3, flight_time: float,
		fall_gravity: float, width: float, seconds: float, hit_damage: int, variant_seed: int) -> Sprite3D:
	var bomb = new()
	bomb.gravity = fall_gravity
	bomb.patch_width = width
	bomb.burn_time = seconds
	bomb.damage = hit_damage
	bomb.variant = variant_seed
	bomb.target_y = target.y
	var time := maxf(flight_time, 0.2)
	bomb.velocity = Vector3((target.x - origin.x) / time,
		(target.y - origin.y + 0.5 * fall_gravity * time * time) / time, 0)
	parent.add_child(bomb)
	bomb.global_position = Vector3(origin.x, origin.y, 0)
	bomb._orient()
	return bomb


func _ready() -> void:
	add_to_group("run_resettable")
	add_to_group("enemy_projectile")
	texture = SHEET
	hframes = 4
	pixel_size = 0.04
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	shaded = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	render_priority = 13


func reset_run() -> void:
	queue_free()


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > LIFETIME:
		queue_free()
		return
	frame = int(_elapsed * 12.0) % hframes
	velocity.y -= gravity * delta
	var from := Vector3(global_position.x, global_position.y, 0)
	var to := from + velocity * delta
	# One-way decks only catch a descending canister.
	var mask := TERRAIN_MASK | (DECK_LAYER if velocity.y <= 0.0 else 0)
	var hit := {}
	for attempt in 4:
		var query := PhysicsRayQueryParameters3D.create(from, to, mask, _passed)
		hit = get_world_3d().direct_space_state.intersect_ray(query)
		var body := hit.get("collider") as CollisionObject3D
		if body == null:
			break
		# Characters (the boss, the player) never catch a canister.
		var actor := body is CharacterBody3D
		var high_deck := not body.collision_layer & TERRAIN_MASK \
			and (hit.position as Vector3).y > target_y + 0.5
		if not actor and not high_deck:
			break
		_passed.append(body.get_rid())
		hit = {}
	if hit.is_empty():
		global_position = Vector3(to.x, to.y, position.z)
		_orient()
		return
	var normal: Vector3 = hit.normal
	if normal.y > 0.6 and velocity.y <= 0.0:
		_burst(hit)
		return
	if normal.y < -0.6:
		velocity.y = minf(velocity.y, 0.0)
	else:
		velocity.x = 0.0
	global_position = Vector3(hit.position.x + normal.x * 0.05, hit.position.y + normal.y * 0.05, position.z)
	_orient()


func _orient() -> void:
	# The art points nose-down; turn the nose along the flight path.
	if velocity.length_squared() > 0.001:
		rotation.z = atan2(velocity.x, -velocity.y)


func _burst(hit: Dictionary) -> void:
	var point: Vector3 = hit.position
	var span := _surface_span(hit)
	var width := minf(patch_width, span.y - span.x)
	var x := clampf(point.x, span.x + width * 0.5, span.y - width * 0.5)
	EFFECT.spawn(get_parent(), Vector3(point.x, point.y + 0.4, 0), BURST, 48, 0.04)
	PATCH.spawn(get_parent(), Vector3(x, point.y, 0), width, burn_time, damage, variant)
	queue_free()


func _surface_span(hit: Dictionary) -> Vector2:
	var fallback := Vector2(hit.position.x - patch_width * 0.5, hit.position.x + patch_width * 0.5)
	var body := hit.collider as CollisionObject3D
	if body == null:
		return fallback
	var shape_owner := body.shape_owner_get_owner(body.shape_find_owner(hit.shape)) as CollisionShape3D
	if shape_owner == null or not shape_owner.shape is BoxShape3D:
		return fallback
	var half := (shape_owner.shape as BoxShape3D).size.x * absf(shape_owner.global_basis.get_scale().x) * 0.5
	return Vector2(shape_owner.global_position.x - half, shape_owner.global_position.x + half)
