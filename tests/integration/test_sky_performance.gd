extends SceneTree

# Presupuesto de escena y colisiones tras agrupar las espinas. No impone FPS al hardware del test.
var checks := 0
var fails := 0
func _initialize() -> void:
	run.call_deferred()
func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("  OK   " if ok else "  FAIL ", label)
func run() -> void:
	change_scene_to_file("res://sky_stairs.tscn")
	await frames(8)
	var player: CharacterBody2D = get_first_node_in_group(&"player")
	player.set_physics_process(false)
	check(get_node_count() < 4000, "la escena completa se mantiene bajo 4000 nodos (%d)" % get_node_count())
	check(get_nodes_in_group(&"training_dummies").size() == 273, "conserva los 273 apoyos y los 18 tramos")
	var boundaries_intact := true
	for name in ["BoundaryLeft", "BoundaryRight", "BoundaryTop"]:
		var boundary: StaticBody2D = current_scene.get_node(name)
		boundaries_intact = boundaries_intact and not boundary.visible and boundary.collision.shape != null and boundary.collision_layer == 2
	check(boundaries_intact, "los límites conservan colisión sin dibujar decoración fuera de la ruta")

	# Ni la franja global larga ni una pared rotada pierden su contacto al agrupar el dibujo.
	for name in ["Pit1", "PitWall9", "ThornsAll"]:
		var hazard: Area2D = current_scene.get_node(name)
		player.current_health = player.max_health
		player.invulnerability_timer = 0.0
		player.global_position = hazard.to_global(Vector2(0, -hazard.size.y * 0.3)) + Vector2(0, 14)
		await frames(6)
		check(player.global_position.distance_to(player.spawn_position) < 2.0 and player.current_health < player.max_health, "%s conserva daño y retorno al checkpoint" % name)

	var far_flyer: Area2D = current_scene.get_node("Seg18F1")
	far_flyer.ruby_core.register_parry()
	var open_before: float = far_flyer.ruby_core.open_time
	await frames(12)
	check(far_flyer.ruby_core.open_time < open_before and far_flyer.ruby_core.is_open(), "la apertura sigue contando fuera de cámara")
	far_flyer.reset_dummy()
	var path_before: float = far_flyer.path_time
	await frames(6)
	check(far_flyer.path_time > path_before, "los voladores lejanos mantienen su trayectoria activa")
	print("RESULTADO: %d/%d OK" % [checks - fails, checks])
	quit(1 if fails else 0)
