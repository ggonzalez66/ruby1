extends Node2D

# Aliado espiritual (mejoras del Gauntlet): silueta de jade de un enemigo que ayuda a Viridy. Solo se mete
# con enemigos que ya están en alerta, para no delatarla. Puede morir (los proyectiles y los contraataques
# le quitan vida) y reaparece junto a Viridy tras RESPAWN_TIME.

const JADE := Color(0.45, 1.0, 0.75, 0.82)
const RESPAWN_TIME := 12.0
const PROJECTILE_RADIUS := 26.0

var player: CharacterBody2D
var max_health := 3
var health := 3
var respawn_left := 0.0
var cooldown := 0.0
var target: Node2D
var sprite: Sprite2D

func _ready() -> void:
	add_to_group(&"spirit_allies")
	z_index = 3
	sprite = Sprite2D.new()
	sprite.texture = load(_art())
	sprite.scale = Vector2.ONE * _art_scale()
	sprite.modulate = JADE
	sprite.offset = _art_offset()
	add_child(sprite)
	health = max_health

func _art() -> String:
	return ""

func _art_scale() -> float:
	return 1.0 / 3.0

func _art_offset() -> Vector2:
	return Vector2.ZERO

func _physics_process(delta: float) -> void:
	player = get_tree().get_first_node_in_group(&"player") as CharacterBody2D
	if player == null:
		return
	if respawn_left > 0.0:
		respawn_left -= delta
		if respawn_left <= 0.0:
			_revive()
		return
	cooldown = maxf(cooldown - delta, 0.0)
	_check_projectiles()
	if respawn_left <= 0.0:
		_act(delta)

func _act(_delta: float) -> void:
	pass

func _check_projectiles() -> void:
	for projectile in get_tree().get_nodes_in_group(&"projectiles"):
		if projectile.get("reflected") != true and projectile.global_position.distance_to(global_position) <= PROJECTILE_RADIUS:
			if projectile.has_method("_destroy"):
				projectile._destroy()
			hurt(1)
			return

func hurt(amount: int) -> void:
	health -= amount
	Fx.puff(get_parent(), global_position, Color(JADE, 0.7))
	if health <= 0:
		_die()

func _die() -> void:
	target = null
	respawn_left = RESPAWN_TIME
	hide()
	Fx.jade_burst(get_parent(), global_position, 0.8)
	Fx.text(get_parent(), global_position + Vector2(0, -40), "¡CAÍDO!", JADE)
	_on_die()

func _on_die() -> void:
	pass

func _revive() -> void:
	health = max_health
	cooldown = 0.0
	global_position = player.global_position + Vector2(-player.facing * 60.0, -60.0)
	show()
	Fx.jade_burst(get_parent(), global_position, 0.6)

func _valid_target(enemy: Variant) -> bool:
	if not is_instance_valid(enemy) or not enemy.visible:
		return false
	var core: Node = enemy.get_node_or_null("RubyCore")
	if core == null or not core.alive() or core.dying or core.locked:
		return false
	var agent: Node = enemy.get_node_or_null("StealthAgent")
	return agent == null or agent.is_aware()

func _nearest_target(reach: float, ground_only: bool) -> Node2D:
	var best: Node2D
	var best_distance := reach
	for enemy in get_tree().get_nodes_in_group(&"ruby_enemies"):
		if not _valid_target(enemy) or (ground_only and (not enemy.has_method("_move_horizontally") or enemy.get_node("RubyCore").boss)):
			continue
		var distance: float = enemy.global_position.distance_to(player.global_position)
		if distance < best_distance:
			best = enemy
			best_distance = distance
	return best

func _center(enemy: Node2D) -> Vector2:
	return enemy.global_position + enemy.impact_offset
