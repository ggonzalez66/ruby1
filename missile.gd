extends "res://projectile.gd"

# Misil del guardián mecha: sale hacia arriba desde el hombro, gira hacia el punto marcado en el suelo
# (cruz roja) y cae acelerando; al tocar algo explota en un radio pequeño. Como cualquier proyectil, el
# rugido lo devuelve, y devuelto vuela contra el mecha.

const BODY := Color(0.36, 0.38, 0.42)
const FLAME := Color(1.0, 0.55, 0.15)
const MARK := Color(1.0, 0.18, 0.12)

var target := Vector2.ZERO
var rise_time := 0.45
var cruise_speed := 520.0
var turn_rate := 4.5
var blast_radius := 48.0
var elapsed := 0.0
var marker: Node2D
var flame: Polygon2D
var exploded := false

func _ready() -> void:
	style = "orb"
	super._ready()
	glow.visible = false
	core.visible = false
	add_child(_poly([Vector2(-10, -3), Vector2(6, -3), Vector2(12, 0), Vector2(6, 3), Vector2(-10, 3)], BODY))
	add_child(_poly([Vector2(-10, -3), Vector2(-14, -6), Vector2(-12, 0), Vector2(-14, 6), Vector2(-10, 3)], BODY.darkened(0.3)))
	flame = _poly([Vector2(-12, -2), Vector2(-24, 0), Vector2(-12, 2)], FLAME)
	add_child(flame)
	marker = Node2D.new()
	marker.top_level = true
	marker.z_index = -1
	marker.draw.connect(_draw_marker)
	add_child(marker)
	marker.global_position = target
	life = 6.0

func _draw_marker() -> void:
	var pulse: float = 0.5 + 0.5 * sin(elapsed * 18.0)
	marker.draw_arc(Vector2.ZERO, blast_radius * 0.6, 0.0, TAU, 20, Color(MARK, 0.5 + 0.4 * pulse), 2.0, true)
	marker.draw_line(Vector2(-12, -12), Vector2(12, 12), Color(MARK, 0.8), 2.0, true)
	marker.draw_line(Vector2(-12, 12), Vector2(12, -12), Color(MARK, 0.8), 2.0, true)

func _physics_process(delta: float) -> void:
	elapsed += delta
	if not reflected and elapsed > rise_time:
		var wanted: Vector2 = (target - global_position).normalized() * cruise_speed * (1.0 + (elapsed - rise_time) * 0.8)
		velocity = velocity.lerp(wanted, clampf(turn_rate * delta, 0.0, 1.0))
	rotation = velocity.angle()
	flame.scale.x = 0.8 + 0.4 * sin(elapsed * 50.0)
	marker.visible = not reflected
	marker.queue_redraw()
	super._physics_process(delta)

func _destroy() -> void:
	if exploded:
		return
	exploded = true
	if not reflected:
		var player := get_tree().get_first_node_in_group(&"player") as Node2D
		if player != null and (player.global_position + Vector2(0, -20)).distance_to(global_position) <= blast_radius:
			player.take_damage(Shine.damage(damage, shine_level), global_position)
	Fx.impact(get_parent(), global_position, [Color(0.4, 0.08, 0.04), FLAME, Color(1.0, 0.95, 0.7)], 1.1)
	Sfx.play("enemy_die", -6.0, 1.3)
	super._destroy()
