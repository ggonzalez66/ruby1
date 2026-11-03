extends "res://run_rest_area.gd"

# El zorro comerciante de la run: un puesto con techo y cartel "SHOP" donde el zorro vende las mejoras
# por rubíes. Al llegar al mostrador se abre la tienda (upgrade_menu.gd en modo tienda: stock limitado
# a STOCK mejoras por visita y reroll pagado); después se puede volver a abrir con {move_up}. La salida a
# la derecha vuelve al mapa.

const UPGRADE_MENU := preload("res://upgrade_menu.gd")
const STOCK := 4
const STALL_X := 2400.0
const COUNTER_HALF := 260.0

var shop_menu: CanvasLayer
var stall: Node2D
var visited_counter := false
var near_counter := false

func _title() -> String:
	return "EL ZORRO COMERCIANTE"

func _build_level() -> void:
	_block(Vector2(width * 0.5, 150), Vector2(width, 300), PLATFORM.Style.GROUND)
	stall = preload("res://fox_stall.gd").new()
	stall.position = Vector2(STALL_X, 0)
	add_child(stall)
	shop_menu = UPGRADE_MENU.new()
	shop_menu.card_size = Vector2(230, 250)
	add_child(shop_menu)
	shop_menu.closed.connect(_on_shop_closed)

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player) or player.dead or shop_menu.is_open():
		return
	near_counter = absf(player.global_position.x - STALL_X) < COUNTER_HALF and player.global_position.y > -200.0
	stall.talking = near_counter
	if not near_counter:
		hint_label.text = "" if visited_counter else "Acércate al puesto del zorro"
		return
	if not visited_counter:
		visited_counter = true
		open_shop()
		return
	hint_label.text = "%s: comerciar con el zorro" % InputHints.binding("move_up")
	if Input.is_action_just_pressed("move_up"):
		open_shop()

func open_shop() -> void:
	hint_label.text = ""
	Sfx.play("ui_select")
	shop_menu.open_shop(STOCK)

func _on_shop_closed() -> void:
	var weapon_player := player
	if is_instance_valid(weapon_player):
		weapon_player.sync_ranged_weapon()
