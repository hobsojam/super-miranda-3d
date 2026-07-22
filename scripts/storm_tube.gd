class_name StormTube
extends Node3D

## An authored, non-branching route represented by a smooth centreline.
## Gameplay will eventually address the world as (lane, distance); this
## prototype only proves the visual half: a camera travelling through a
## genuinely curved tube rather than a displaced 2D vanishing point.

@export var radius: float = 12.0
@export var lane_count: int = 16
@export var ring_samples: int = 220
@export var guide_ring_interval: int = 5
@export var travel_speed: float = 18.0
@export var guide_overdraw_enabled: bool = true

var route_length: float = 0.0
var _samples: Array[RouteSample] = []
var _wall: MeshInstance3D
var _guides: MeshInstance3D

class RouteSample:
	var position: Vector3
	var tangent: Vector3
	var right: Vector3
	var up: Vector3

func _ready() -> void:
	_build_route()
	_build_meshes()

func sample_at_distance(distance: float) -> RouteSample:
	var progress: float = clampf(distance / route_length, 0.0, 1.0)
	var index_f: float = progress * float(_samples.size() - 1)
	var i: int = int(floor(index_f))
	var next_i: int = mini(i + 1, _samples.size() - 1)
	var blend: float = index_f - float(i)
	var result: RouteSample = RouteSample.new()
	result.position = _samples[i].position.lerp(_samples[next_i].position, blend)
	result.tangent = _samples[i].tangent.lerp(_samples[next_i].tangent, blend).normalized()
	result.right = _samples[i].right.lerp(_samples[next_i].right, blend).normalized()
	result.up = result.tangent.cross(result.right).normalized()
	return result

func set_guide_overdraw_enabled(enabled: bool) -> void:
	if guide_overdraw_enabled == enabled:
		return
	guide_overdraw_enabled = enabled
	if _guides:
		_guides.queue_free()
	_guides = MeshInstance3D.new()
	_guides.mesh = _build_guide_mesh()
	_guides.material_override = _guide_material()
	add_child(_guides)

func _build_route() -> void:
	_samples.clear()
	# Each point is deliberately modest in lateral displacement: the player
	# should feel a succession of readable corners, not lose the route behind
	# an opaque wall. It is a finite first-stage route; R restarts the preview.
	var control_points := PackedVector3Array(
		[
			Vector3(0, 0, 0),
			Vector3(0, 0, -70),
			Vector3(30, 12, -145),
			Vector3(78, -8, -220),
			Vector3(48, -40, -305),
			Vector3(-20, -28, -390),
			Vector3(-62, 16, -480),
			Vector3(-24, 48, -575),
			Vector3(44, 22, -665),
			Vector3(66, -24, -755),
			Vector3(18, -48, -850),
			Vector3(-35, -10, -940),
			Vector3(-72, 28, -1040),
			Vector3(-18, 58, -1155),
			Vector3(58, 34, -1275),
			Vector3(86, -20, -1405),
			Vector3(22, -60, -1540),
			Vector3(-54, -34, -1680),
			Vector3(-88, 22, -1835),
			Vector3(-28, 66, -1990),
			Vector3(54, 46, -2155),
			Vector3(92, -18, -2325),
			Vector3(30, -66, -2505),
			Vector3(-62, -38, -2685),
			Vector3(-96, 30, -2870),
			Vector3(-18, 72, -3060),
			Vector3(68, 38, -3250),
		]
	)
	var previous_right: Vector3 = Vector3.RIGHT
	var previous_position: Vector3 = Vector3.ZERO
	for i in ring_samples:
		var t: float = float(i) / float(ring_samples - 1)
		var position: Vector3 = _catmull_rom(control_points, t)
		var tangent: Vector3 = (
			_catmull_rom(control_points, minf(t + 0.002, 1.0))
			- _catmull_rom(control_points, maxf(t - 0.002, 0.0))
		).normalized()
		var right: Vector3 = (previous_right - tangent * previous_right.dot(tangent)).normalized()
		if right.length_squared() < 0.001:
			right = Vector3.UP.cross(tangent).normalized()
		var up: Vector3 = tangent.cross(right).normalized()
		var sample: RouteSample = RouteSample.new()
		sample.position = position
		sample.tangent = tangent
		sample.right = right
		sample.up = up
		_samples.append(sample)
		if i > 0:
			route_length += position.distance_to(previous_position)
		previous_position = position
		previous_right = right

func _catmull_rom(points: PackedVector3Array, t: float) -> Vector3:
	var scaled: float = t * float(points.size() - 1)
	var i: int = int(floor(scaled))
	var local_t: float = scaled - float(i)
	var p0: Vector3 = points[maxi(i - 1, 0)]
	var p1: Vector3 = points[clampi(i, 0, points.size() - 1)]
	var p2: Vector3 = points[mini(i + 1, points.size() - 1)]
	var p3: Vector3 = points[mini(i + 2, points.size() - 1)]
	var t2: float = local_t * local_t
	var t3: float = t2 * local_t
	return 0.5 * (
		(2.0 * p1)
		+ (-p0 + p2) * local_t
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)

func _build_meshes() -> void:
	_wall = MeshInstance3D.new()
	_wall.mesh = _build_wall_mesh()
	_wall.material_override = _wall_material()
	add_child(_wall)
	_guides = MeshInstance3D.new()
	_guides.mesh = _build_guide_mesh()
	_guides.material_override = _guide_material()
	add_child(_guides)

func _ring_point(sample: RouteSample, angle: float, r: float = radius) -> Vector3:
	return sample.position + sample.right * cos(angle) * r + sample.up * sin(angle) * r

func _build_wall_mesh() -> ArrayMesh:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in _samples.size() - 1:
		for lane in lane_count:
			var next_lane: int = (lane + 1) % lane_count
			var a0: float = TAU * float(lane) / float(lane_count)
			var a1: float = TAU * float(next_lane) / float(lane_count)
			var c: Color = Color(0.025, 0.075, 0.20).lerp(
				Color(0.05, 0.14, 0.34),
				0.5 + 0.5 * sin(float(lane) * 1.7)
			)
			c.a = 1.0
			var u0: float = float(lane) / float(lane_count)
			var u1: float = float(lane + 1) / float(lane_count)
			var v0: float = float(row) / float(_samples.size() - 1)
			var v1: float = float(row + 1) / float(_samples.size() - 1)
			_add_textured_quad(
				surface,
				_ring_point(_samples[row], a0),
				_ring_point(_samples[row + 1], a0),
				_ring_point(_samples[row + 1], a1),
				_ring_point(_samples[row], a1),
				c,
				Vector2(u0, v0),
				Vector2(u0, v1),
				Vector2(u1, v1),
				Vector2(u1, v0)
			)
	return surface.commit()

func _build_guide_mesh() -> ArrayMesh:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var line_color: Color = Color(0.08, 0.95, 1.0, 0.9 if guide_overdraw_enabled else 1.0)
	# Longitudinal lane dividers.
	for lane in lane_count:
		var angle: float = TAU * float(lane) / float(lane_count)
		for row in _samples.size() - 1:
			_add_ribbon(
				surface,
				_ring_point(_samples[row], angle),
				_ring_point(_samples[row + 1], angle),
				_samples[row].tangent,
				0.075,
				line_color
			)
	# Repeating hoops provide speed and make the bend legible.
	for row in range(0, _samples.size(), guide_ring_interval):
		for lane in lane_count:
			var a0: float = TAU * float(lane) / float(lane_count)
			var a1: float = TAU * float(lane + 1) / float(lane_count)
			_add_ribbon(
				surface,
				_ring_point(_samples[row], a0),
				_ring_point(_samples[row], a1),
				_samples[row].tangent,
				0.12,
				line_color
			)
	return surface.commit()

func _add_quad(
	surface: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	color: Color
) -> void:
	for vertex in [a, b, c, a, c, d]:
		surface.set_color(color)
		surface.add_vertex(vertex)

func _add_textured_quad(
	surface: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	color: Color,
	uv_a: Vector2,
	uv_b: Vector2,
	uv_c: Vector2,
	uv_d: Vector2
) -> void:
	var vertices: Array[Vector3] = [a, b, c, a, c, d]
	var uvs: Array[Vector2] = [uv_a, uv_b, uv_c, uv_a, uv_c, uv_d]
	for index in vertices.size():
		surface.set_color(color)
		surface.set_uv(uvs[index])
		surface.add_vertex(vertices[index])

func _add_ribbon(
	surface: SurfaceTool,
	a: Vector3,
	b: Vector3,
	facing: Vector3,
	width: float,
	color: Color
) -> void:
	var sideways: Vector3 = (b - a).cross(facing).normalized() * width
	_add_quad(surface, a - sideways, b - sideways, b + sideways, a + sideways, color)

func _wall_material() -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	var shader: Shader = Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 5; i++) {
		value += noise(p) * amplitude;
		p *= 2.03;
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	float depth_scroll = UV.y * 82.0 + TIME * 10.5;
	float lane_grid = UV.x * 48.0;
	vec2 cell = floor(vec2(lane_grid, depth_scroll));
	vec2 local = fract(vec2(lane_grid, depth_scroll));
	float cell_noise = hash(cell);
	float dash_body = smoothstep(0.24, 0.06, abs(local.y - 0.5));
	float dash_width = smoothstep(0.50, 0.08, abs(local.x - 0.5));
	float dash = dash_body * dash_width * smoothstep(0.50, 0.98, cell_noise);

	vec2 long_uv = vec2(UV.x * 9.0 + TIME * 0.08, UV.y * 16.0 + TIME * 0.7);
	float tunnel_grain = fbm(long_uv);
	float radial_stripe = smoothstep(0.90, 1.0, sin(UV.x * 96.0 + tunnel_grain * 2.5) * 0.5 + 0.5);
	float ring_pulse = 0.74 + 0.26 * smoothstep(0.52, 1.0, sin(UV.y * 120.0 + TIME * 5.0) * 0.5 + 0.5);

	float lightning_seed = fbm(vec2(UV.x * 18.0 + TIME * 0.6, UV.y * 26.0 - TIME * 1.6));
	float lightning_line = abs(sin(UV.x * 36.0 + UV.y * 118.0 + lightning_seed * 6.0 - TIME * 4.9));
	float flash = smoothstep(0.90, 1.0, sin(TIME * 4.7 + UV.y * 31.0) * 0.5 + 0.5);
	float lightning = smoothstep(0.991, 0.999, lightning_line) * flash;

	vec3 deep = vec3(0.004, 0.014, 0.055);
	vec3 tunnel_blue = vec3(0.018, 0.110, 0.230);
	vec3 dash_blue = vec3(0.060, 0.310, 0.520);
	vec3 electric = vec3(0.160, 0.980, 1.000);
	vec3 color = mix(deep, tunnel_blue, COLOR.b * 0.75 + tunnel_grain * 0.28);
	color += dash_blue * dash * 1.45;
	color += electric * radial_stripe * 0.08;
	color *= ring_pulse;
	color += electric * lightning * 2.5;

	ALBEDO = color;
	EMISSION = color * 0.42 + electric * lightning * 3.0 + dash_blue * dash * 0.55;
}
"""
	material.shader = shader
	return material

func _flat_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _guide_material() -> Material:
	if guide_overdraw_enabled:
		return _guide_overdraw_material()
	var material: StandardMaterial3D = _flat_material()
	material.emission_enabled = true
	material.emission = Color(0.0, 0.92, 1.0)
	material.emission_energy_multiplier = 2.8
	return material

func _guide_overdraw_material() -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	var shader: Shader = Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, blend_add;

void fragment() {
	vec3 electric = vec3(0.0, 0.92, 1.0);
	ALBEDO = electric;
	EMISSION = electric * 2.8;
	ALPHA = COLOR.a;
}
"""
	material.shader = shader
	return material
