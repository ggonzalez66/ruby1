extends RefCounted

# Profiles are latched when an action starts; losing/equipping a weapon cannot change a hit mid-action.
const Catalog := preload("res://weapon_catalog.gd")
const Motion := preload("res://enemy_launch_motion.gd")
var player: CharacterBody2D
var weapon: StringName = &"unarmed"
var enabled := false
var ground_slam := false
var speed := 1.0
var reach := 1.0
var bonus := 0
var stagger := 0.0
var pulses := 1
var elapsed := 0.0
var duration := 0.0
var pulse := 0
var victims: Dictionary = {}
var carried: Dictionary = {}

func begin() -> void:
	clear()
	if player.weapons == null or player.liquid_beast or player.weapons.active:
		return
	enabled = player.attack_mode in [player.ATTACK_GROUND_CHARGED, player.ATTACK_LIGHT_CHARGED_AIR, player.ATTACK_SPIN, player.ATTACK_UPPERCUT, player.ATTACK_HEAVY]
	if not enabled:
		return
	weapon = player.weapons.current_weapon()
	var profile: Dictionary = Catalog.COMMON[weapon]
	speed = profile.speed
	player.attack_cooldown_timer /= speed
	reach = profile.reach
	bonus = profile.bonus
	stagger = profile.stagger
	pulses = profile.pulses if player.attack_mode != player.ATTACK_HEAVY else 1
	ground_slam = weapon in [&"axe", &"hammer"] and player.attack_mode == player.ATTACK_HEAVY
	duration = player.attack_timer

func clear() -> void:
	if is_instance_valid(player) and is_instance_valid(player.attack_effects):
		player.attack_effects.scale = Vector2.ONE
	for enemy in carried:
		if is_instance_valid(enemy):
			enemy.set_physics_process(carried[enemy])
			if enemy.has_method("launch_to"):
				enemy.launch_to(enemy.global_position, 0.01, 0.0)
	carried.clear()
	victims.clear()
	enabled = false
	ground_slam = false
	speed = 1.0
	reach = 1.0
	bonus = 0
	stagger = 0.0
	pulses = 1
	elapsed = 0.0
	pulse = 0

func tick(delta: float) -> void:
	if not enabled:
		return
	elapsed += delta * speed
	if duration > 0.0:
		var next := mini(pulses - 1, int(elapsed / duration * pulses))
		if next != pulse:
			pulse = next
			player.attack_targets_hit.clear()

func can_hit(enemy: Area2D) -> bool:
	if not enabled:
		return true
	# One hit per target per pulse, even when overlap signals and refresh run together.
	if victims.get(enemy, -1) == pulse:
		return false
	var ray := PhysicsRayQueryParameters2D.create(player.global_position + Vector2(0, -25), player._get_target_center(enemy), 2)
	return player.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func damage(base: int) -> int:
	if enabled and weapon in [&"sword", &"glaive"]:
		base = 1 if pulse > 0 else base + (1 if player.attack_mode == player.ATTACK_HEAVY else 0)
	return maxi(1, roundi(float(base + bonus) * player.damage_multiplier)) if enabled else base

func on_hit(enemy: Area2D) -> void:
	if not enabled:
		return
	victims[enemy] = pulse
	var core: Node = enemy.get_node_or_null("RubyCore")
	if core != null:
		core.stagger(stagger)
	if ground_slam and core != null and not core.boss and not core.locked and core.alive():
		if not carried.has(enemy):
			carried[enemy] = enemy.is_physics_processing()
			enemy.set_physics_process(false)

func geometry() -> void:
	if not enabled:
		return
	player.hitbox_shape.scale *= reach
	player.slash_visual.scale *= reach
	player.slash_area_visual.scale *= reach
	player.slash_outline.scale *= reach

func carry() -> void:
	if not ground_slam:
		return
	for enemy in carried:
		if not is_instance_valid(enemy):
			continue
		var shape: CollisionShape2D = enemy.get("collision_shape")
		if shape != null:
			Motion.move_to(enemy, shape, player.global_position + Vector2(0, 12))

func impact() -> void:
	if not ground_slam:
		return
	var center: Vector2 = player.global_position + Vector2(0, -25)
	var radius := 130.0 if weapon == &"axe" else 170.0
	for enemy in player.weapons._targets(center, Vector2(radius * 2, 110)):
		if enemy.has_method("take_hit"):
			enemy.take_hit(center, player.facing, damage(4 if weapon == &"axe" else 6))
			var core: Node = enemy.get_node_or_null("RubyCore")
			if core != null:
				core.stagger(stagger * 2.0)
	Fx.jade_splash(player.get_parent(), center, Vector2.UP, radius / 100.0)
