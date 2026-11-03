extends Area2D

# Ruby de una pata de la araña (spider_boss.gd). La araña la coloca cada fotograma sobre la tibia de su
# pata. Funciona como un enemigo normal con su RubyCore: los golpes le bajan la vida y, a cero, el ruby
# queda expuesto (DYING) para ejecutarlo con un pesado (cura como cualquier ejecución); si nadie lo
# ejecuta, se rompe solo al acabarse el tiempo. Al romperse, la pata queda inutilizada.

const RUBY_CORE_SCRIPT := preload("res://ruby_core.gd")

var spider: Node2D
var index := 0
var max_health := 36
var current_health := 36
var impact_offset := Vector2.ZERO
var core_size := 15.0
var creature_kind := &"machine"
var broken := false
var flash_left := 0.0
var ruby_core: Node2D

func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	current_health = max_health
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 38.0
	shape.shape = circle
	add_child(shape)
	ruby_core = RUBY_CORE_SCRIPT.new()
	ruby_core.name = "RubyCore"
	add_child(ruby_core)
	ruby_core.z_index = 9

func _physics_process(delta: float) -> void:
	flash_left = maxf(flash_left - delta, 0.0)

func take_hit(_source_position: Vector2, _direction: int = 1, damage: int = 1, play_sound: bool = true) -> void:
	if broken or ruby_core.locked:
		return
	if ruby_core.dying:
		flash_left = 0.1
		ruby_core.hit_while_dying()
		return
	current_health = maxi(current_health - maxi(damage, 0), 0)
	flash_left = 0.1
	if current_health > 0 and play_sound:
		Sfx.play("enemy_hurt", 0.0, 0.7)
	_update_health_bar()
	if current_health == 0:
		ruby_core.enter_dying()
		Fx.text(get_parent(), global_position + Vector2(0, -50), "¡RUBY EXPUESTO!", Color(1.0, 0.5, 0.45))

func on_shine_hit(_direction: int, _strength: float) -> void:
	# Las patas no se empujan.
	flash_left = 0.1

func _update_health_bar() -> void:
	if is_instance_valid(ruby_core):
		ruby_core.queue_redraw()

func _die() -> void:
	if broken:
		return
	broken = true
	set_deferred("monitorable", false)
	Sfx.play("enemy_die", 2.0, 0.6)
	if spider != null and is_instance_valid(spider):
		spider.on_leg_destroyed(self)

func alive() -> bool:
	return not broken
