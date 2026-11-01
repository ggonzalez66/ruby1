extends Node

# Autoload "Upgrades": rubíes y mejoras de una partida del Gauntlet. Ejecutar da rubíes (la cadena suma uno
# más por eslabón; un guardián da 10) y al superar una ronda se elige una mejora gratis y se compran más.
# También guarda el arma a distancia equipada y el Enfoque, el recurso del hechizo de RB (focus_spell.gd).
# Fuera del Gauntlet no está activo: has() y strike() no cambian nada y el arma es la lanza.

signal rubies_changed(total: int, gained: int)
signal owned_changed

const ELEMENT_STATUS := preload("res://element_status.gd")
const STATUS_NAME := "ElementStatus"
const REROLL_COST := 5
const BOSS_RUBIES := 10
const RUBY_COLOR := Color(1.0, 0.22, 0.3)
# Tipos de ataque que pueden llevar un elemento (uno por tipo).
const SLOTS := {"light": "ataques ligeros", "heavy": "ataques pesados", "uppercut": "uppercut"}
const RANGED_SLOT := "ranged"
const RANGED_NAME := "arma a distancia"
const ELEMENTS := {
	"electric": {"title": "Electricidad", "price": 12, "color": Color(1.0, 0.92, 0.35),
		"text": "Más daño y salta a los enemigos cercanos. 3 marcas aturden y el aturdimiento también salta. Eficaz contra máquinas."},
	"fire": {"title": "Fuego", "price": 12, "color": Color(1.0, 0.5, 0.15),
		"text": "Quema con daño en el tiempo. Eficaz contra bestias."},
	"ice": {"title": "Hielo", "price": 12, "color": Color(0.55, 0.85, 1.0),
		"text": "Ralentiza y acumula hielo. Con 3 queda congelado: un pesado aéreo rompe el hielo y pega muchísimo."},
}
const DEFAULT_WEAPON := "spear"
# Cambiar de arma reemplaza la actual: el menú pide confirmación.
const WEAPONS := {
	"spear": {"title": "Lanza de jade", "price": 8, "color": Color(0.8, 1.0, 0.65),
		"text": "Vuelve a la lanza: marca, atrae y se llama de vuelta."},
	"pistol": {"title": "Pistola", "price": 14, "color": Color(1.0, 0.9, 0.6),
		"text": "Mantén el gatillo: muchos disparos de poco daño. El elemento sale cada 3 disparos."},
	"grenade": {"title": "Granada de hielo", "price": 16, "color": Color(0.55, 0.85, 1.0),
		"text": "Explota, hiela y suelta mini racimos. Tiene enfriamiento."},
	"railgun": {"title": "Railgun", "price": 18, "color": Color(0.75, 0.55, 1.0),
		"text": "Lenta. Un láser atraviesa a todos los enemigos, con mucho impacto y retroceso."},
}
const CATALOG := {
	"backflip_iframes": {"title": "Backflip fantasma", "price": 8, "color": Color(0.7, 0.85, 1.0),
		"text": "Eres invulnerable mientras gira el backflip."},
	"frontflip_iframes": {"title": "Frontflip fantasma", "price": 8, "color": Color(0.7, 0.85, 1.0),
		"text": "Eres invulnerable mientras gira el frontflip."},
	"sss_run": {"title": "Estampida", "price": 10, "color": Color(1.0, 0.18, 0.4),
		"text": "Correr en rango SSS a través de los enemigos los daña."},
	"spirit_hawk": {"title": "Halcón espiritual", "price": 14, "color": Color(0.45, 1.0, 0.75),
		"text": "Un halcón aliado ataca a los enemigos que te descubren. Si muere, reaparece tras un rato."},
	"spirit_hound": {"title": "Sabueso espiritual", "price": 14, "color": Color(0.45, 1.0, 0.75),
		"text": "Un sabueso aliado inmoviliza enemigos en el suelo. Si muere, reaparece tras un rato."},
	"screw_reflect": {"title": "Giro reflector", "price": 8, "color": Color(1.0, 0.82, 0.35),
		"text": "El screw attack devuelve los proyectiles."},
	"spear_pierce": {"title": "Punta perforante", "price": 10, "color": Color(0.45, 1.0, 0.75), "max": 3,
		"text": "La lanza o la pistola atraviesan 1 enemigo más y hacen más daño. Acumulable."},
	"time_stop": {"title": "Reloj detenido", "price": 22, "color": Color(0.6, 0.9, 1.0),
		"text": "El hechizo de Enfoque detiene a los enemigos y sus proyectiles mientras tú sigues moviéndote. Gasta más Enfoque."},
	"focus_reserve": {"title": "Reserva de Enfoque", "price": 9, "color": Color(0.6, 0.9, 1.0), "max": 2,
		"text": "Más Enfoque máximo. Acumulable."},
	"long_cloak": {"title": "Manto largo", "price": 8, "color": Color(0.5, 1.0, 0.72),
		"text": "La invisibilidad al salir de un bush dura 4 s más."},
	"temper": {"title": "Temple elemental", "price": 10, "color": Color(0.85, 0.85, 0.9),
		"text": "Los elementos enemigos te duran la mitad."},
}
const PIERCING_WEAPONS := ["spear", "pistol"]
const FOCUS_MAX := 100.0
const FOCUS_PER_RESERVE := 40.0
const FOCUS_PER_HIT := 2.0
const FOCUS_PER_EXECUTION := 30.0

var active := false
var rubies := 0
var owned := {}
# slot -> elemento.
var element_slots := {}
var weapon := DEFAULT_WEAPON
var focus := FOCUS_MAX

func begin_run() -> void:
	active = true
	rubies = 0
	owned.clear()
	element_slots.clear()
	weapon = DEFAULT_WEAPON
	focus = FOCUS_MAX
	rubies_changed.emit(rubies, 0)
	owned_changed.emit()

func end_run() -> void:
	active = false

func has(id: String) -> bool:
	return active and owned.has(id)

func level(id: String) -> int:
	return int(owned.get(id, 0)) if active else 0

func element_for(slot: String) -> String:
	return String(element_slots.get(slot, "")) if active else ""

func ranged_weapon() -> String:
	return weapon if active else DEFAULT_WEAPON

func focus_capacity() -> float:
	return FOCUS_MAX + FOCUS_PER_RESERVE * level("focus_reserve")

func add_focus(amount: float) -> void:
	if active:
		focus = clampf(focus + amount, 0.0, focus_capacity())

func add_rubies(amount: int) -> void:
	if not active or amount <= 0:
		return
	rubies += amount
	rubies_changed.emit(rubies, amount)

func chain_rubies(chain: int, boss: bool) -> int:
	# Cada eslabón de la cadena da uno más que el anterior; el guardián siempre da lo suyo.
	return BOSS_RUBIES if boss else maxi(chain, 1)

func spend(amount: int) -> bool:
	if not active or rubies < amount:
		return false
	rubies -= amount
	rubies_changed.emit(rubies, -amount)
	return true

# ---------- Cartas

func offers(count: int, exclude: Array = []) -> Array:
	var pool: Array = []
	for id in CATALOG:
		if int(owned.get(id, 0)) < int(CATALOG[id].get("max", 1)) and (id != "spear_pierce" or weapon in PIERCING_WEAPONS):
			pool.append(_card(id))
	for id in WEAPONS:
		if id != weapon:
			pool.append(_weapon_card(id))
	var free_slots: Array = SLOTS.keys().filter(func(slot): return not element_slots.has(slot))
	for element in ELEMENTS:
		if not free_slots.is_empty():
			pool.append(_element_card(element, free_slots.pick_random()))
		# La granada ya hiela por sí misma.
		if not element_slots.has(RANGED_SLOT) and not (element == "ice" and weapon == "grenade"):
			pool.append(_element_card(element, RANGED_SLOT))
	pool = pool.filter(func(card): return not card["key"] in exclude)
	pool.shuffle()
	return pool.slice(0, count)

func _card(id: String) -> Dictionary:
	var data: Dictionary = CATALOG[id]
	var title: String = data["title"]
	if data.has("max") and owned.has(id):
		title += " %d" % (int(owned[id]) + 1)
	return {"key": id, "id": id, "title": title, "text": data["text"], "price": data["price"], "color": data["color"]}

func _weapon_card(id: String) -> Dictionary:
	var data: Dictionary = WEAPONS[id]
	return {"key": "weapon_" + id, "id": "weapon", "weapon": id, "title": data["title"], "text": data["text"], "price": data["price"], "color": data["color"]}

func _element_card(element: String, slot: String) -> Dictionary:
	var data: Dictionary = ELEMENTS[element]
	var ranged: bool = slot == RANGED_SLOT
	return {"key": ("ranged_" if ranged else "") + element, "id": "element", "element": element, "slot": slot,
		"title": "%s en %s" % [data["title"], RANGED_NAME if ranged else SLOTS[slot]], "text": data["text"], "price": data["price"], "color": data["color"]}

func can_take(card: Dictionary) -> bool:
	# Una carta ya en pantalla puede dejar de valer tras comprar otra: cada tipo de ataque lleva un elemento.
	match card["id"]:
		"element":
			return not element_slots.has(card["slot"])
		"weapon":
			return card["weapon"] != weapon
	return true

func replaces_weapon(card: Dictionary) -> bool:
	return card["id"] == "weapon"

func weapon_title() -> String:
	return WEAPONS[weapon]["title"]

func grant(card: Dictionary) -> void:
	match card["id"]:
		"element":
			element_slots[card["slot"]] = card["element"]
		"weapon":
			weapon = card["weapon"]
		_:
			owned[card["id"]] = int(owned.get(card["id"], 0)) + 1
	owned_changed.emit()

func buy(card: Dictionary) -> bool:
	if not spend(int(card["price"])):
		return false
	grant(card)
	return true

# ---------- Elementos

func kind_of(enemy: Node) -> StringName:
	var kind: Variant = enemy.get("creature_kind")
	return kind if kind != null else &"machine"

func status_of(enemy: Node) -> Node:
	var status: Node = enemy.get_node_or_null(STATUS_NAME)
	if status == null:
		status = ELEMENT_STATUS.new()
		status.name = STATUS_NAME
		enemy.add_child(status)
	return status

func strike(enemy: Node2D, slot: String, damage: int, aerial_heavy := false) -> int:
	# Devuelve el daño final del golpe y aplica el estado del elemento de ese tipo de ataque.
	if not active:
		return damage
	# Sin tipo de ataque (las balas sin cargar de la pistola) no recarga Enfoque.
	if not slot.is_empty():
		add_focus(FOCUS_PER_HIT)
	var status: Node = enemy.get_node_or_null(STATUS_NAME)
	if status != null and aerial_heavy and status.is_frozen():
		return status.shatter(damage)
	var element := element_for(slot)
	return damage if element.is_empty() else status_of(enemy).apply(element, damage)

func imbue(enemy: Node2D, element: String, damage: int) -> int:
	# Un arma con su propio elemento (la granada siempre hiela).
	return status_of(enemy).apply(element, damage) if active else damage
