extends Node2D

const FIRE := preload("res://jade_fire_visual.gd")
const GLOW := preload("res://shaders/charge_glow.gdshader")
var target: Node2D
var tint: ShaderMaterial
var originals: Array = []
var flames: Array[Sprite2D] = []
var anchors: Array[Vector2] = []
var clock := 0.0

func _ready() -> void:
	tint = ShaderMaterial.new()
	tint.shader = GLOW
	tint.set_shader_parameter("glow_color", Color(0.12, 0.85, 0.38))
	tint.set_shader_parameter("glow_amount", 0.72)
	var body_visual: Node2D = target.get("visual")
	if body_visual != null:
		_tint(body_visual)
		for item in body_visual.find_children("*", "CanvasItem", true, false):
			_tint(item)
	else:
		# Los tiradores construyen cuerpo, soporte y cañón directamente bajo el Area2D.
		for item in target.get_children():
			_tint(item)
	var collision: CollisionShape2D = target.get("collision_shape")
	if collision == null:
		for child in target.get_children():
			if child is CollisionShape2D:
				collision = child
				break
	var rect := Rect2(Vector2(-22, -28), Vector2(44, 56))
	if collision != null:
		if collision.shape is RectangleShape2D:
			rect = Rect2(collision.position - collision.shape.size * 0.5, collision.shape.size)
		elif collision.shape is CircleShape2D:
			var radius: float = collision.shape.radius
			rect = Rect2(collision.position - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	for index in range(7):
		anchors.append(rect.position + rect.size * Vector2([0.25, 0.75, 0.15, 0.85, 0.4, 0.7, 0.3][index], 0.15 + index * 0.12))
		var flame := Sprite2D.new()
		flame.texture = FIRE.TEXTURE
		flame.hframes = 2
		flame.vframes = 2
		flame.z_index = 5
		flame.modulate.a = 0.72
		add_child(flame)
		flames.append(flame)
	_process(0.0)

func _tint(item: Node) -> void:
	if item is Polygon2D or item is Sprite2D or item is Line2D:
		originals.append({"node": weakref(item), "material": item.material, "parent_material": item.use_parent_material})
		item.use_parent_material = false
		item.material = tint

func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	clock += delta
	for index in range(flames.size()):
		var flame := flames[index]
		flame.global_position = target.to_global(anchors[index])
		flame.frame = (int(clock * 18.0) + index) % 4
		flame.scale = Vector2(0.032, 0.025) * (1.0 + 0.15 * sin(clock * 21.0 + index))
		flame.global_rotation = -PI * 0.5 + 0.12 * sin(clock * 12.0 + index)

func _exit_tree() -> void:
	for saved in originals:
		var item: CanvasItem = saved.node.get_ref()
		if is_instance_valid(item) and item.material == tint:
			item.material = saved.material
			item.use_parent_material = saved.parent_material
