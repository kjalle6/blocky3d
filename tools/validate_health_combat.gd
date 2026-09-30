extends SceneTree
## Numerical health, duplicate-hit rejection, interruption, and stomp bounce.
const PLAYER := preload("res://scenes/player/pixel_player_character.tscn")
const ENEMIES := [
	preload("res://scenes/enemies/pixel_patrol_enemy.tscn"),
	preload("res://scenes/enemies/pixel_skater_enemy.tscn"),
	preload("res://scenes/enemies/handgun_enemy.tscn"),
]
const MACHINES := [
	preload("res://scenes/enemies/green_zone_tank.tscn"),
	preload("res://scenes/enemies/green_zone_boss.tscn"),
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var player := PLAYER.instantiate() as PlayerCharacter
	world.add_child(player)
	player.set_physics_process(false)
	assert(player.health.current == 100)
	assert(not player.receive_enemy_hit(Vector3.ZERO, null), "Missing hit data must not invent damage.")
	assert(player.health.current == 100)
	assert(player.receive_enemy_hit(Vector3.ZERO, CombatHit.new(17, &"test_variable_damage")))
	assert(player.health.current == 83, "The attacking source owns damage; it is not always 25.")
	player.reset_at(Transform3D.IDENTITY)
	for expected in [75, 50, 25, 0]:
		var hit := CombatHit.new(25, &"test", Vector3.ZERO)
		assert(player.receive_enemy_hit(Vector3.ZERO, hit))
		assert(player.health.current == expected)
		assert(not player.receive_enemy_hit(Vector3.ZERO, hit))
	assert(player.is_dead())
	player.reset_at(Transform3D.IDENTITY)
	player.health.reset(200)
	player.kill()
	assert(player.is_dead() and player.health.current == 0, "Lethal hazards bypass upgraded HP.")
	player.reset_at(Transform3D.IDENTITY)
	player.set("_attack_remaining", 0.3)
	player.set("_active_attack_weapon_id", PlayerWeapon.KNIFE)
	player.receive_enemy_hit(Vector3.ZERO, CombatHit.new(25, &"test_enemy"))
	assert(not player.is_attacking() and player.get("_attack_lock_remaining") > 0.0)
	assert(player.health.heal(25))
	assert(not player.health.heal(25), "Full HP does not accept a heal.")
	player.inventory.add(&"basic_heal", 7)
	player.inventory.equip(1, &"basic_heal")
	assert(not player.use_quick_item(0))
	assert(player.inventory.count(&"basic_heal") == 7)
	player.receive_enemy_hit(Vector3.ZERO, CombatHit.new(25, &"test_enemy"))
	assert(player.use_quick_item(1))
	assert(player.health.current == 100 and player.inventory.count(&"basic_heal") == 6)
	assert(not player.use_quick_item(0), "Both slots reference one stack and share the brief use cooldown.")
	var hit_pair := CombatHit.new(25, &"paired_bullet")
	player.receive_enemy_hit(Vector3.ZERO, hit_pair)
	assert(not player.receive_enemy_hit(Vector3.ZERO, hit_pair))
	assert(player.health.current == 75)
	assert(player.get("_attack_lock_remaining") >= player.healing_remaining, "Damage cannot shorten the healing attack lock.")
	assert(player.receive_enemy_hit(Vector3.ZERO, CombatHit.new(25, &"different_attacker")))
	assert(player.health.current == 50, "Distinct attacks are not blocked by global invulnerability.")
	player.set("_attack_lock_remaining", 0.2)
	player.configure_weapon_ownership([PlayerWeapon.KNIFE, PlayerWeapon.HANDGUN], PlayerWeapon.HANDGUN)
	Input.action_press("attack")
	player._update_attack(0.0)
	Input.action_release("attack")
	assert(not player.is_attacking(), "Switching weapons cannot bypass the healing/hurt attack lock.")
	var profile := preload("res://resources/combat/bat.tres")
	for packed in ENEMIES:
		var enemy: Node3D = packed.instantiate()
		world.add_child(enemy)
		enemy.set_physics_process(false)
		assert(enemy.health.current == 50)
		var knife := CombatHit.new(25, &"knife", Vector3.ZERO)
		assert(enemy.receive_melee_hit(Vector3.ZERO, knife))
		assert(enemy.health.current == 25 and not enemy.is_defeated())
		assert(not enemy.receive_melee_hit(Vector3.ZERO, knife))
		assert(enemy.health.current == 25)
		assert(enemy.receive_melee_hit(Vector3.ZERO, CombatHit.new(25, &"knife")))
		assert(enemy.is_defeated())
		enemy.reset_run()
		enemy.set_physics_process(false)
		enemy.health.reset(100)
		enemy.receive_stomp(player)
		assert(enemy.health.current == 50 and not enemy.is_defeated())
		assert(player.velocity.y > 0.0, "A surviving stomp still bounces.")
		enemy.reset_run()
		enemy.set_physics_process(false)
		if enemy is StompableEnemy3D:
			enemy.set("_attack_remaining", 0.4)
			enemy.receive_melee_hit(Vector3.ZERO)
			assert(not enemy.is_attacking() and enemy.get("_attack_cooldown_remaining") > 0.0)
		else:
			enemy.set("_state", HandgunEnemy3D.CombatState.FIRING)
			enemy.set("_sequence_shots_remaining", 3)
			enemy.receive_melee_hit(Vector3.ZERO)
			assert(enemy.get("_state") == HandgunEnemy3D.CombatState.RECOVERY)
			assert(enemy.get("_sequence_shots_remaining") == 0)
		assert(profile.maximum_hp == 50, "Shared authored values must remain unchanged.")
		enemy.free()
	_validate_machine_armor(world, player)
	world.free()
	print("Health combat checks passed.")
	quit()


func _validate_machine_armor(world: Node3D, player: PlayerCharacter) -> void:
	for packed in MACHINES:
		var machine: Node3D = packed.instantiate()
		world.add_child(machine)
		machine.set_physics_process(false)
		var maximum: int = machine.combat.maximum_hp
		assert(machine.combat.knife_damage_multiplier == 0.5)
		var ordinary: Node3D = ENEMIES[2].instantiate()
		world.add_child(ordinary)
		ordinary.set_physics_process(false)
		var shared := CombatHit.new(25, &"knife")
		assert(machine.receive_melee_hit(Vector3.ZERO, shared))
		assert(machine.health.current == maximum - 12)
		assert(not machine.receive_melee_hit(Vector3.ZERO, shared))
		assert(machine.health.current == maximum - 12, "Duplicates must not change fractional damage either.")
		assert(ordinary.receive_melee_hit(Vector3.ZERO, shared))
		assert(ordinary.health.current == 25 and shared.amount == 25,
			"One swing can hit an armored machine and an unarmored enemy without sharing resistance.")
		assert(machine.receive_projectile_hit(Vector3.ZERO, CombatHit.new(25, &"bullet")))
		assert(machine.health.current == maximum - 37, "Bullets must retain full damage after an odd knife hit.")
		assert(machine.receive_melee_hit(Vector3.ZERO, CombatHit.new(25, &"knife")))
		assert(machine.health.current == maximum - 50, "Two knife hits total exactly 25 damage.")
		machine.reset_run()
		machine.set_physics_process(false)
		# The optional legacy knife call must also pass through armor.
		assert(machine.receive_melee_hit(Vector3.ZERO))
		assert(machine.health.current == maximum - 12)
		machine.reset_run()
		machine.set_physics_process(false)
		assert(machine.receive_melee_hit(Vector3.ZERO))
		assert(machine.health.current == maximum - 12, "Reset clears the previous life's half-point.")
		var before_stomp: int = machine.health.current
		if machine is TankEnemy3D:
			assert(not machine.receive_melee_hit(Vector3.ZERO, CombatHit.new(50, &"stomp")))
			assert(machine.health.current == before_stomp)
			machine._state = HandgunEnemy3D.CombatState.FIRING
			machine._phase_remaining = 0.37
			machine.velocity.x = 1.25
			assert(machine.receive_melee_hit(Vector3.ZERO))
			assert(machine._state == HandgunEnemy3D.CombatState.FIRING and machine._phase_remaining == 0.37
				and machine.velocity.x == 1.25, "Knife armor must retain uninterrupted tank attacks and motion.")
		else:
			assert(not machine.receive_melee_hit(Vector3.ZERO, CombatHit.new(50, &"stomp")))
			machine.receive_stomp(player)
			assert(machine.health.current == before_stomp and not player.is_ground_held(),
				"An unrelated stomp callback must neither damage the boss nor deploy smoke.")
		machine.reset_run()
		assert(not player.is_ground_held())
		machine.set_physics_process(false)
		var knife_hits := maximum * 2 / 25
		for index in knife_hits:
			assert(machine.receive_melee_hit(Vector3.ZERO, CombatHit.new(25, &"knife")))
			assert(machine.health.current == maximum - floori((index + 1) * 12.5))
			assert(machine.is_defeated() == (index == knife_hits - 1))
		assert(not machine.receive_melee_hit(Vector3.ZERO, CombatHit.new(25, &"knife")))
		ordinary.free()
		machine.free()
	var health := HealthState.new()
	var defense: CombatProfile = preload("res://resources/combat/tank.tres")
	health.reset(100)
	health.damage(CombatHit.new(25, &"knife"), defense)
	assert(health.heal(5))
	health.damage(CombatHit.new(25, &"knife"), defense)
	assert(health.current == 80, "Partial healing preserves fractional damage.")
	health.damage(CombatHit.new(25, &"knife"), defense)
	assert(health.heal(100))
	health.damage(CombatHit.new(25, &"knife"), defense)
	assert(health.current == 88, "A full heal clears fractional damage.")
	print("Machine armor passed: exact half knife damage, mixed recipients, duplicates, bullets, stomp rules, reset, healing, uninterrupted tank fire and 16/24-hit knife defeats.")
