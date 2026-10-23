extends SceneTree

var checks := 0
var fails := 0
func _initialize() -> void:
	_run.call_deferred()
func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("  OK   " if ok else "  FAIL ", label)
func _run() -> void:
	var session := root.get_node("RunSession")
	session.storage_directory = "user://sky_records_test_%s" % Time.get_ticks_usec()
	change_scene_to_file("res://sky_stairs.tscn")
	await frames(12)
	var player: CharacterBody2D = get_first_node_in_group(&"player")
	check(session.level == current_scene and session.running, "la escalera inicia cronómetro y grabación propios")
	var previous: Node2D = current_scene.get_node("StartIsland")
	var previous_gap := 0.0
	var previous_count := 0
	var all_growing := true
	var supports_connected := true
	for segment in range(1, 19):
		var landing: Node2D = current_scene.get_node("Seg%dLand" % segment)
		var edge: float = previous.position.x + previous.size.x * 0.5
		var landing_edge: float = landing.position.x - landing.size.x * 0.5
		var gap: float = landing_edge - edge
		all_growing = all_growing and gap > previous_gap
		var count := 0
		var last_x := edge
		while current_scene.has_node("Seg%dF%d" % [segment, count + 1]):
			count += 1
			var flyer: Node2D = current_scene.get_node("Seg%dF%d" % [segment, count])
			supports_connected = supports_connected and flyer.position.x - last_x <= 311
			last_x = flyer.position.x
		supports_connected = supports_connected and landing_edge - last_x <= 311 and count >= previous_count
		previous_gap = gap
		previous_count = count
		previous = landing
	check(all_growing and previous_gap >= 6150, "los 18 fosos crecen progresivamente hasta 6150 px")
	check(supports_connected, "las cadenas se alargan y conservan apoyos a distancia alcanzable")
	player.set_physics_process(false)
	session.elapsed = 20.0
	player.position += Vector2(300, -200)
	session._record_frame()
	var result: Dictionary = session.finish_stage()
	check(result.get("best", false) and result.get("saved", false), "completar guarda récord y replay de la escalera")
	var record: Dictionary = session.load_record(session.SKY_STAGE)
	check(record.get("times", []).size() == 1 and not record.get("frames", []).is_empty(), "el Top 10 conserva el tiempo y sus frames")
	session.begin_run(player, false)
	check(is_instance_valid(session.ghost), "una nueva run muestra el fantasma del mejor tiempo")
	session.elapsed = 2.0
	session._update_ghost()
	check(session.ghost.visible and session.ghost.texture != null, "el replay reproduce los sprites al ritmo del cronómetro")
	session.elapsed = 30.0
	result = session.finish_stage()
	record = session.load_record(session.SKY_STAGE)
	check(not result.get("best", true) and record.get("times", []).size() == 2 and record.get("best", 0) == 20.0, "un tiempo más lento entra en ranking y conserva el mejor fantasma")
	check(session.load_record("res://main.tscn").is_empty(), "récords de torre y escalera independientes")
	session.begin_run(player, false)
	session.elapsed = 12.0
	var sun: Area2D = current_scene.get_node("Sun")
	sun._on_body_entered(player)
	check(session.finished and session.result.get("best", false) and sun.merging, "la llegada al sol completa y guarda la run antes de la fusión")
	session.show_records()
	var labels: Array[Node] = session.records_panel.find_children("*", "Label", true, false)
	check(labels.any(func(label): return label.text == "ESCALERA AL CIELO"), "la UI de Top 10 incluye la escalera")
	print("RESULTADO: %d/%d OK" % [checks - fails, checks])
	quit(1 if fails else 0)
