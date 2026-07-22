class_name StormPlayer
extends Node3D

signal fire_requested

@export var wall_offset: float = 0.82
@export var damage_flash_time: float = 0.14
@export var fire_cooldown: float = 0.18

var _hull: MeshInstance3D
var _left_edge: MeshInstance3D
var _right_edge: MeshInstance3D
var _core: MeshInstance3D
var _hull_material: StandardMaterial3D
var _left_edge_material: StandardMaterial3D
var _right_edge_material: StandardMaterial3D
var _core_material: StandardMaterial3D
var _flash_material: StandardMaterial3D
var _damage_flash_timer: float = 0.0
var _invulnerable_visual_timer: float = 0.0
var _fire_timer: float = 0.0
var _fire_enabled: bool = false

func _ready() -> void:
	_build_model()

func _process(delta: float) -> void:
	_damage_flash_timer = maxf(_damage_flash_timer - delta, 0.0)
	_invulnerable_visual_timer = maxf(_invulnerable_visual_timer - delta, 0.0)
	tick_fire_input(delta, Input.is_key_pressed(KEY_SPACE))
	_update_damage_visuals()

func set_route_pose(sample: StormTube.RouteSample, lane_angle: float, tube_radius: float) -> void:
	var radial: Vector3 = sample.right * cos(lane_angle) + sample.up * sin(lane_angle)
	var forward: Vector3 = sample.tangent.normalized()
	var side: Vector3 = radial.cross(forward).normalized()

	global_position = sample.position + radial * (tube_radius * wall_offset)
	global_basis = Basis(side, radial, -forward).orthonormalized()

func play_damage_feedback(invulnerable_time: float) -> void:
	_damage_flash_timer = damage_flash_time
	_invulnerable_visual_timer = maxf(_invulnerable_visual_timer, invulnerable_time)
	_update_damage_visuals()

func set_fire_enabled(enabled: bool) -> void:
	_fire_enabled = enabled

func reset_fire_cooldown() -> void:
	_fire_timer = 0.0

func tick_fire_input(delta: float, fire_held: bool) -> void:
	_fire_timer = maxf(_fire_timer - delta, 0.0)
	if not _fire_enabled or not fire_held or _fire_timer > 0.0:
		return
	fire_requested.emit()
	_fire_timer = fire_cooldown

func _build_model() -> void:
	_flash_material = _material(Color(0.85, 1.0, 1.0), Color(0.3, 1.0, 1.0), 4.8)

	_hull = MeshInstance3D.new()
	_hull.mesh = _build_claw_hull_mesh()
	_hull_material = _material(Color(0.02, 0.28, 0.20), Color(0.08, 0.75, 0.45), 1.1)
	_hull.material_override = _hull_material
	add_child(_hull)

	_left_edge = _edge_strip(Vector3(-0.74, 0.16, 0.88), Vector3(-0.18, 0.22, -1.28))
	add_child(_left_edge)

	_right_edge = _edge_strip(Vector3(0.74, 0.16, 0.88), Vector3(0.18, 0.22, -1.28))
	add_child(_right_edge)

	_core = MeshInstance3D.new()
	var core_mesh: SphereMesh = SphereMesh.new()
	core_mesh.radius = 0.18
	core_mesh.height = 0.36
	_core.mesh = core_mesh
	_core.position = Vector3(0.0, 0.27, -0.35)
	_core_material = _material(Color(0.72, 1.0, 0.18), Color(0.55, 1.0, 0.08), 2.8)
	_core.material_override = _core_material
	add_child(_core)

func _build_claw_hull_mesh() -> ArrayMesh:
	var top: Array[Vector3] = [
		Vector3(0.0, 0.24, -1.65),
		Vector3(0.62, 0.18, -0.58),
		Vector3(0.92, 0.12, 0.96),
		Vector3(0.18, 0.16, 0.56),
		Vector3(0.0, 0.12, 1.05),
		Vector3(-0.18, 0.16, 0.56),
		Vector3(-0.92, 0.12, 0.96),
		Vector3(-0.62, 0.18, -0.58)
	]
	var bottom: Array[Vector3] = []
	for point in top:
		bottom.append(Vector3(point.x * 0.82, -0.12, point.z * 0.92))

	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hull_color: Color = Color(0.02, 0.34, 0.24)
	for i in range(1, top.size() - 1):
		_add_triangle(surface, top[0], top[i], top[i + 1], hull_color)
	for i in range(1, bottom.size() - 1):
		_add_triangle(surface, bottom[0], bottom[i + 1], bottom[i], hull_color.darkened(0.35))
	for i in top.size():
		var next_i: int = (i + 1) % top.size()
		_add_quad(
			surface,
			top[i],
			top[next_i],
			bottom[next_i],
			bottom[i],
			hull_color.darkened(0.16)
		)
	return surface.commit()

func _edge_strip(a: Vector3, b: Vector3) -> MeshInstance3D:
	var strip: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	var length: float = a.distance_to(b)
	mesh.size = Vector3(0.08, 0.08, length)
	strip.mesh = mesh
	strip.position = a.lerp(b, 0.5)
	var forward: Vector3 = (b - a).normalized()
	var side: Vector3 = Vector3.UP.cross(forward).normalized()
	if side.length_squared() < 0.001:
		side = Vector3.RIGHT
	var up: Vector3 = forward.cross(side).normalized()
	strip.basis = Basis(side, up, forward).orthonormalized()
	var edge_material: StandardMaterial3D = _material(
		Color(0.45, 1.0, 0.72),
		Color(0.18, 1.0, 0.62),
		3.0
	)
	strip.material_override = edge_material
	if _left_edge_material == null:
		_left_edge_material = edge_material
	else:
		_right_edge_material = edge_material
	return strip

func _add_triangle(
	surface: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	color: Color
) -> void:
	for vertex in [a, b, c]:
		surface.set_color(color)
		surface.add_vertex(vertex)

func _add_quad(
	surface: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	color: Color
) -> void:
	_add_triangle(surface, a, b, c, color)
	_add_triangle(surface, a, c, d, color)

func _material(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = albedo
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material

func _update_damage_visuals() -> void:
	if _hull == null:
		return
	var flashing: bool = _damage_flash_timer > 0.0
	_hull.material_override = _flash_material if flashing else _hull_material
	_left_edge.material_override = _flash_material if flashing else _left_edge_material
	_right_edge.material_override = _flash_material if flashing else _right_edge_material
	_core.material_override = _flash_material if flashing else _core_material

	if _invulnerable_visual_timer <= 0.0:
		visible = true
		return
	visible = fmod(_invulnerable_visual_timer, 0.12) > 0.035
