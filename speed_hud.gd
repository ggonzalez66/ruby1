extends PanelContainer

# Escala de presentación del mundo: 32 unidades = 1 metro; no altera la física ni el bonus.
const UNITS_PER_METRE := 32.0
const KMH_PER_UNIT := 3.6 / UNITS_PER_METRE
var player: CharacterBody2D
var value_label: Label
var bonus_label: Label
var meter: ProgressBar
var displayed_speed := 0.0

func _ready() -> void:
	name = "SpeedMeter"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(28, 82)
	custom_minimum_size = Vector2(128, 28)
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	add_child(column)
	var row := HBoxContainer.new()
	column.add_child(row)
	value_label = Label.new()
	value_label.add_theme_font_size_override("font_size", 14)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value_label)
	bonus_label = Label.new()
	bonus_label.add_theme_font_size_override("font_size", 10)
	bonus_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(bonus_label)
	meter = ProgressBar.new()
	meter.custom_minimum_size.y = 2
	meter.show_percentage = false
	meter.max_value = 2.5
	column.add_child(meter)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.5, 0.7, 0.55, 0.15)
	meter.add_theme_stylebox_override("background", background)
	var foreground := StyleBoxFlat.new()
	foreground.bg_color = Color.WHITE
	meter.add_theme_stylebox_override("fill", foreground)
	_update_reading()

func _process(_delta: float) -> void:
	_update_reading()

func _update_reading() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as CharacterBody2D
	displayed_speed = absf(player.velocity.x) if is_instance_valid(player) and not player.dead else 0.0
	var sprint: float = player.sprint_speed if is_instance_valid(player) else 560.0
	var ratio := displayed_speed / maxf(sprint, 1.0)
	var bonus := Ferocity.speed_bonus_rate(displayed_speed, sprint)
	value_label.text = "%d km/h" % roundi(displayed_speed * KMH_PER_UNIT)
	bonus_label.text = "+" if bonus > 0.0 else ""
	var color := Color(0.7, 0.85, 0.73).lerp(Color(1.0, 0.78, 0.45), clampf((ratio - 1.0) / 1.5, 0.0, 1.0))
	value_label.modulate = color
	bonus_label.modulate = color
	meter.modulate = color
	meter.value = ratio
	modulate.a = 0.45 if displayed_speed < 1.0 else 0.8
