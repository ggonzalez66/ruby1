extends Area2D

# Franja de espinas: daña a Rengar al tocarla. El origen es el nivel del suelo.
# Con send_to_checkpoint (plataformeo de la etapa final) además lo devuelve al último checkpoint, para
# que no se puedan cruzar caminando y aguantando el daño.

@export var size := Vector2(250, 18)
@export var damage := 10
@export var send_to_checkpoint := false

const THORN_DARK := Color(0.16, 0.07, 0.2)
const THORN_LIGHT := Color(0.55, 0.25, 0.55)
const SPIKES_PER_MESH := 64

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	# Hitbox algo más baja y estrecha que las puntas para que rozarlas al saltar no cuente.
	rect.size = Vector2(max(size.x - 8.0, 4.0), size.y * 0.6)
	shape.shape = rect
	shape.position = Vector2(0, -size.y * 0.3)
	add_child(shape)

	var count: int = max(int(size.x / 14.0), 1)
	var width: float = size.x / count
	# Un bloque de triángulos por tramo, en vez de un nodo por pincho. Los bloques pequeños
	# permiten al renderer descartar lo que queda fuera de cámara incluso en franjas de 95 000 px.
	for first in range(0, count, SPIKES_PER_MESH):
		var vertices := PackedVector3Array()
		var colors := PackedColorArray()
		for index in range(first, mini(first + SPIKES_PER_MESH, count)):
			var left: float = (index - first) * width
			var tip_height: float = size.y * (0.75 + 0.25 * ((index * 7) % 3) / 2.0)
			vertices.append_array(PackedVector3Array([Vector3(left, 0, 0), Vector3(left + width * 0.5, -tip_height, 0), Vector3(left + width, 0, 0)]))
			var color := THORN_DARK if index % 2 == 0 else THORN_LIGHT
			colors.append_array(PackedColorArray([color, color, color]))
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_COLOR] = colors
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var strip := MeshInstance2D.new()
		strip.position.x = -size.x * 0.5 + first * width
		strip.mesh = mesh
		add_child(strip)

func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		if send_to_checkpoint and body.has_method("return_to_checkpoint"):
			body.return_to_checkpoint(damage)
		elif body.has_method("take_damage"):
			# El daño viene desde abajo: el retroceso lanza hacia arriba.
			body.take_damage(damage, Vector2(body.global_position.x, global_position.y + 40.0))
