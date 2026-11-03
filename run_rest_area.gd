extends Node2D

# Base de los territorios sin combate de la run (fuente de curación y zorro comerciante): jungla de
# fondo, Viridy, HUD, pausa, música, rubíes arriba y la salida a la derecha que vuelve al mapa.
# Cada territorio construye su escenario en _build_level().

const PLAYER := preload("res://playerr.tscn")
const JUNGLE := preload("res://jungle_background.gd")
const HUD := preload("res://hud.gd")
const PAUSE := preload("res://pause_menu.gd")
const MUSIC_PLAYER := preload("res://music_player.gd")
const EXIT := preload("res://run_exit.gd")
const DEMO := preload("res://demo_complete.gd")
const PLATFORM := preload("res://platform.gd")

@export var width := 4000.0
@export var player_start := Vector2(200, -2)

var player: CharacterBody2D
var exit_sign: Area2D
var title_layer: CanvasLayer
var rubies_label: Label
var hint_label: Label

func _ready() -> void:
	get_tree().paused = false
	TimeControl.set_slow_motion(false)
	add_child(JUNGLE.new())
	_build_level()
	for x in [-30.0, width + 30.0]:
		_block(Vector2(x, -700), Vector2(60, 2200), PLATFORM.Style.WALL)
	player = PLAYER.instantiate()
	player.name = "Playerr"
	player.position = player_start
	add_child(player)
	add_child(HUD.new())
	var music := AudioStreamPlayer.new()
	music.set_script(MUSIC_PLAYER)
	add_child(music)
	var pause: CanvasLayer = PAUSE.new()
	pause.name = "PauseMenu"
	add_child(pause)
	var demo: CanvasLayer = DEMO.new()
	demo.name = "DemoComplete"
	demo.final_screen = true
	add_child(demo)
	exit_sign = EXIT.new()
	exit_sign.position = Vector2(width - 160.0, _exit_ground())
	exit_sign.label_text = "SALIDA · AL MAPA"
	exit_sign.entered.connect(_leave)
	add_child(exit_sign)
	_build_info()

func _build_level() -> void:
	pass

func _exit_ground() -> float:
	return 0.0

func _leave() -> void:
	RunState.return_to_map()

func _block(center: Vector2, size: Vector2, style: int) -> StaticBody2D:
	var block: StaticBody2D = PLATFORM.new()
	block.position = center
	block.size = size
	block.style = style
	add_child(block)
	return block

func _title() -> String:
	return ""

func _build_info() -> void:
	title_layer = CanvasLayer.new()
	title_layer.layer = 12
	add_child(title_layer)
	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_CENTER_TOP)
	anchor.position.y = 66
	title_layer.add_child(anchor)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.11, 0.09, 0.85)
	style.border_color = Color(0.55, 0.82, 0.45, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 2
	style.content_margin_bottom = 3
	panel.add_theme_stylebox_override("panel", style)
	anchor.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var title := Label.new()
	title.text = _title()
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.93, 1.0, 0.86))
	row.add_child(title)
	rubies_label = Label.new()
	rubies_label.add_theme_font_size_override("font_size", 16)
	rubies_label.add_theme_color_override("font_color", Upgrades.RUBY_COLOR.lightened(0.25))
	row.add_child(rubies_label)
	panel.resized.connect(func(): panel.position.x = -panel.size.x * 0.5)
	hint_label = Label.new()
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.offset_left = -400
	hint_label.offset_right = 400
	hint_label.offset_top = -90
	hint_label.offset_bottom = -60
	hint_label.add_theme_font_size_override("font_size", 20)
	hint_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))
	hint_label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.02))
	hint_label.add_theme_constant_override("outline_size", 6)
	title_layer.add_child(hint_label)
	Upgrades.rubies_changed.connect(_on_rubies_changed)
	_on_rubies_changed(Upgrades.rubies, 0)

func _on_rubies_changed(total: int, _gained: int) -> void:
	rubies_label.text = "RUBÍES: %d" % total
