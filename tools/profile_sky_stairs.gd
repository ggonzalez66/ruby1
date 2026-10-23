extends SceneTree

# Ejecutar con renderizado real para comparar antes/después en la misma máquina:
# RUBY1_SKIP_COUNTDOWN=1 godot --path . --disable-vsync --max-fps 0 -s res://tools/profile_sky_stairs.gd
# La GPU, resolución y renderer deben ser iguales entre muestras; headless no mide el dibujo.
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var start := Time.get_ticks_usec()
	var scene: Node = load("res://sky_stairs.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	print("SKY load_ms=%.1f nodes=%d" % [(Time.get_ticks_usec() - start) / 1000.0, get_node_count()])
	var player: CharacterBody2D = get_first_node_in_group(&"player")
	player.set_physics_process(false)
	var camera: Camera2D = player.get_node("Camera2D")
	for point in ["StartIsland", "Seg9Land", "Summit"]:
		var platform: Node2D = current_scene.get_node(point)
		player.global_position = platform.global_position - Vector2(0, platform.size.y * 0.5)
		camera.reset_smoothing()
		camera.force_update_scroll()
		for i in range(12):
			await process_frame
		var times: Array[float] = []
		var previous := Time.get_ticks_usec()
		for i in range(60):
			await process_frame
			var now := Time.get_ticks_usec()
			times.append((now - previous) / 1000.0)
			previous = now
		times.sort()
		print("SKY %s median_ms=%.2f p95_ms=%.2f" % [point, times[30], times[57]])
	quit()
