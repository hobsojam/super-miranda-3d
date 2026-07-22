class_name StageMarkerFactory
extends RefCounted

static func build_enemy_marker(kind: String) -> Node3D:
	var marker: Node3D = Node3D.new()
	marker.set_meta("kind", kind)
	var material: StandardMaterial3D = material_for_kind(kind)
	var accent: StandardMaterial3D = accent_material_for_kind(kind)
	match kind:
		"splitter":
			_add_sphere_part(marker, 0.62, Vector3.ZERO, material)
			_add_prism_part(
				marker,
				Vector3(0.72, 0.48, 1.35),
				Vector3(-0.82, 0.0, 0.12),
				Vector3(0.0, 0.0, 0.65),
				accent
			)
			_add_prism_part(
				marker,
				Vector3(0.72, 0.48, 1.35),
				Vector3(0.82, 0.0, 0.12),
				Vector3(0.0, 0.0, -0.65),
				accent
			)
			_add_box_part(
				marker,
				Vector3(2.05, 0.12, 0.18),
				Vector3(0.0, 0.0, -0.2),
				Vector3.ZERO,
				accent
			)
			_add_sphere_part(marker, 0.24, Vector3(-0.58, 0.36, -0.42), accent)
			_add_sphere_part(marker, 0.24, Vector3(0.58, -0.36, -0.42), accent)
		"spiker":
			_add_prism_part(marker, Vector3(0.62, 0.62, 2.75), Vector3.ZERO, Vector3.ZERO, material)
			_add_box_part(
				marker,
				Vector3(1.65, 0.08, 0.18),
				Vector3(0.0, 0.0, -0.35),
				Vector3(0.0, 0.0, 0.35),
				accent
			)
			_add_box_part(
				marker,
				Vector3(1.15, 0.08, 0.16),
				Vector3(0.0, 0.0, 0.45),
				Vector3(0.0, 0.0, -0.45),
				accent
			)
			_add_prism_part(
				marker,
				Vector3(0.28, 0.28, 0.9),
				Vector3(-0.48, 0.16, 0.82),
				Vector3(0.0, 0.0, 0.35),
				accent
			)
			_add_prism_part(
				marker,
				Vector3(0.28, 0.28, 0.9),
				Vector3(0.48, -0.16, 0.82),
				Vector3(0.0, 0.0, -0.35),
				accent
			)
		"pulsar":
			var spin: Node3D = Node3D.new()
			spin.name = "Spin"
			marker.add_child(spin)
			_add_sphere_part(spin, 0.58, Vector3.ZERO, material)
			_add_box_part(spin, Vector3(2.05, 0.08, 0.08), Vector3.ZERO, Vector3.ZERO, accent)
			_add_box_part(spin, Vector3(0.08, 2.05, 0.08), Vector3.ZERO, Vector3.ZERO, accent)
			_add_box_part(spin, Vector3(0.08, 0.08, 1.45), Vector3.ZERO, Vector3.ZERO, accent)
		"exploder":
			var pulse: Node3D = Node3D.new()
			pulse.name = "Pulse"
			marker.add_child(pulse)
			_add_sphere_part(pulse, 0.74, Vector3.ZERO, material)
			_add_box_part(pulse, Vector3(2.0, 0.07, 0.07), Vector3.ZERO, Vector3(0.0, 0.0, 0.55), accent)
			_add_box_part(pulse, Vector3(0.07, 2.0, 0.07), Vector3.ZERO, Vector3(0.0, 0.0, -0.55), accent)
			_add_box_part(pulse, Vector3(0.07, 0.07, 2.0), Vector3.ZERO, Vector3(0.55, 0.0, 0.0), accent)
		"gate_post":
			var pulse: Node3D = Node3D.new()
			pulse.name = "Pulse"
			marker.add_child(pulse)
			_add_box_part(pulse, Vector3(0.22, 1.85, 0.22), Vector3.ZERO, Vector3.ZERO, material)
			_add_box_part(pulse, Vector3(0.54, 0.16, 0.34), Vector3(0.0, 0.84, 0.0), Vector3.ZERO, accent)
			_add_box_part(pulse, Vector3(0.54, 0.16, 0.34), Vector3(0.0, -0.84, 0.0), Vector3.ZERO, accent)
			_add_box_part(pulse, Vector3(0.08, 1.55, 0.42), Vector3(-0.22, 0.0, 0.0), Vector3.ZERO, accent)
			_add_box_part(pulse, Vector3(0.08, 1.55, 0.42), Vector3(0.22, 0.0, 0.0), Vector3.ZERO, accent)
			_add_sphere_part(pulse, 0.24, Vector3.ZERO, accent)
		"gate_field":
			var pulse: Node3D = Node3D.new()
			pulse.name = "Pulse"
			marker.add_child(pulse)
			_add_box_part(pulse, Vector3(1.72, 0.12, 0.12), Vector3.ZERO, Vector3.ZERO, material)
			_add_box_part(
				pulse,
				Vector3(1.34, 0.06, 0.08),
				Vector3(0.0, 0.18, 0.0),
				Vector3.ZERO,
				accent
			)
			_add_box_part(
				pulse,
				Vector3(1.34, 0.06, 0.08),
				Vector3(0.0, -0.18, 0.0),
				Vector3.ZERO,
				accent
			)
		"spike":
			_add_prism_part(marker, Vector3(0.42, 0.42, 1.45), Vector3.ZERO, Vector3.ZERO, material)
			_add_prism_part(
				marker,
				Vector3(0.32, 0.32, 1.05),
				Vector3(-0.36, 0.0, 0.12),
				Vector3(0.0, 0.85, 0.0),
				accent
			)
			_add_prism_part(
				marker,
				Vector3(0.32, 0.32, 1.05),
				Vector3(0.36, 0.0, 0.12),
				Vector3(0.0, -0.85, 0.0),
				accent
			)
		_:
			_add_prism_part(marker, Vector3(0.82, 0.52, 2.05), Vector3.ZERO, Vector3.ZERO, material)
			_add_box_part(
				marker,
				Vector3(1.45, 0.08, 0.34),
				Vector3(0.0, 0.0, 0.35),
				Vector3(0.0, 0.0, -0.45),
				accent
			)
			_add_box_part(
				marker,
				Vector3(0.78, 0.08, 0.28),
				Vector3(-0.48, 0.0, -0.32),
				Vector3(0.0, 0.0, 0.62),
				accent
			)
			_add_box_part(
				marker,
				Vector3(0.78, 0.08, 0.28),
				Vector3(0.48, 0.0, -0.32),
				Vector3(0.0, 0.0, -0.62),
				accent
			)
	return marker

static func build_pickup_marker(kind: String) -> Node3D:
	var marker: Node3D = Node3D.new()
	var material: StandardMaterial3D = pickup_material(kind)
	var accent: StandardMaterial3D = pickup_accent_material(kind)
	match kind:
		"purge":
			var spin: Node3D = Node3D.new()
			spin.name = "Spin"
			marker.add_child(spin)
			_add_sphere_part(spin, 0.4, Vector3.ZERO, material)
			_add_box_part(
				spin,
				Vector3(1.55, 0.12, 0.08),
				Vector3(0.0, 0.44, 0.0),
				Vector3(0.0, 0.0, 0.18),
				accent
			)
			_add_box_part(
				spin,
				Vector3(1.55, 0.12, 0.08),
				Vector3(0.0, -0.44, 0.0),
				Vector3(0.0, 0.0, -0.18),
				accent
			)
			_add_box_part(
				spin,
				Vector3(0.16, 1.28, 0.08),
				Vector3(-0.52, 0.0, 0.0),
				Vector3(0.0, 0.0, -0.22),
				accent
			)
			_add_box_part(
				spin,
				Vector3(0.16, 1.28, 0.08),
				Vector3(0.52, 0.0, 0.0),
				Vector3(0.0, 0.0, 0.22),
				accent
			)
			_add_sphere_part(spin, 0.13, Vector3(-0.78, 0.42, 0.0), accent)
			_add_sphere_part(spin, 0.13, Vector3(0.78, -0.42, 0.0), accent)
		_:
			var spin: Node3D = Node3D.new()
			spin.name = "Spin"
			marker.add_child(spin)
			_add_sphere_part(spin, 0.36, Vector3.ZERO, material)
			_add_box_part(spin, Vector3(1.32, 0.2, 0.2), Vector3.ZERO, Vector3.ZERO, accent)
			_add_box_part(spin, Vector3(0.2, 1.32, 0.2), Vector3.ZERO, Vector3.ZERO, accent)
	return marker

static func build_bullet_marker() -> Node3D:
	var marker: Node3D = Node3D.new()
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = 0.16
	mesh.height = 2.8
	mesh_instance.mesh = mesh
	mesh_instance.rotation_degrees.x = 90.0
	mesh_instance.material_override = bullet_material()
	marker.add_child(mesh_instance)
	return marker

static func build_enemy_bolt_marker() -> Node3D:
	var marker: Node3D = Node3D.new()
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = 0.18
	mesh.height = 2.1
	mesh_instance.mesh = mesh
	mesh_instance.rotation_degrees.x = 90.0
	mesh_instance.material_override = enemy_bolt_material()
	marker.add_child(mesh_instance)
	return marker

static func build_burst_marker() -> Node3D:
	var burst: Node3D = Node3D.new()
	for i in 8:
		var shard: MeshInstance3D = MeshInstance3D.new()
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(0.08, 0.08, 0.9)
		shard.mesh = mesh
		var angle: float = TAU * float(i) / 8.0
		shard.position = Vector3(cos(angle), sin(angle), 0.0) * 0.65
		shard.rotation = Vector3(0.0, 0.0, angle)
		shard.material_override = burst_material()
		burst.add_child(shard)
	return burst

static func animate_enemy_art(marker: Node3D, kind: String) -> void:
	var time: float = float(Time.get_ticks_msec()) * 0.001
	match kind:
		"pulsar":
			var spin: Node3D = marker.get_node_or_null("Spin") as Node3D
			if spin:
				spin.rotation = Vector3(time * 2.1, time * 1.2, time * 2.8)
		"exploder":
			var pulse: Node3D = marker.get_node_or_null("Pulse") as Node3D
			if pulse:
				var scale_amount: float = 1.0 + 0.13 * sin(time * 11.0)
				pulse.scale = Vector3.ONE * scale_amount
				pulse.rotation = Vector3(time * 1.4, time * 0.9, time * 1.8)
		"gate_post", "gate_field":
			var pulse: Node3D = marker.get_node_or_null("Pulse") as Node3D
			if pulse:
				var scale_y: float = 1.0 + 0.08 * sin(time * 8.0)
				pulse.scale = Vector3(1.0, scale_y if kind == "gate_post" else 1.0, 1.0)

static func animate_pickup_art(marker: Node3D, kind: String) -> void:
	var time: float = float(Time.get_ticks_msec()) * 0.001
	marker.scale = Vector3.ONE * (1.0 + 0.08 * sin(time * 6.5))
	match kind:
		"purge":
			var spin: Node3D = marker.get_node_or_null("Spin") as Node3D
			if spin:
				spin.rotation = Vector3(0.0, 0.0, time * 1.8)
		_:
			var spin: Node3D = marker.get_node_or_null("Spin") as Node3D
			if spin:
				spin.rotation.z = time * 1.6

static func material_for_kind(kind: String) -> StandardMaterial3D:
	var color: Color = Color(1.0, 0.25, 0.25)
	var emission: Color = Color(1.0, 0.08, 0.08)
	match kind:
		"splitter":
			color = Color(1.0, 0.55, 0.08)
			emission = Color(1.0, 0.28, 0.02)
		"spiker":
			color = Color(0.95, 0.25, 0.95)
			emission = Color(0.9, 0.06, 1.0)
		"pulsar":
			color = Color(1.0, 0.95, 0.18)
			emission = Color(1.0, 0.78, 0.05)
		"exploder":
			color = Color(1.0, 0.92, 0.72)
			emission = Color(1.0, 0.16, 0.08)
		"gate_post":
			color = Color(0.10, 0.58, 0.74)
			emission = Color(0.0, 0.82, 1.0)
		"gate_field":
			color = Color(0.02, 0.32, 0.44)
			emission = Color(0.0, 0.58, 0.78)
		"spike":
			color = Color(0.75, 0.15, 0.95)
			emission = Color(0.9, 0.05, 1.0)
	return _unshaded_material(color, emission, 2.2)

static func accent_material_for_kind(kind: String) -> StandardMaterial3D:
	var color: Color = Color(1.0, 0.55, 1.0)
	var emission: Color = Color(1.0, 0.15, 1.0)
	match kind:
		"splitter":
			color = Color(1.0, 0.86, 0.18)
			emission = Color(1.0, 0.62, 0.04)
		"spiker", "spike":
			color = Color(1.0, 0.18, 1.0)
			emission = Color(0.95, 0.0, 1.0)
		"pulsar":
			color = Color(1.0, 1.0, 0.58)
			emission = Color(1.0, 0.96, 0.12)
		"exploder":
			color = Color(1.0, 0.32, 0.18)
			emission = Color(1.0, 0.08, 0.0)
		"gate_post":
			color = Color(0.64, 1.0, 1.0)
			emission = Color(0.05, 1.0, 1.0)
		"gate_field":
			color = Color(0.22, 0.95, 1.0)
			emission = Color(0.0, 0.84, 1.0)
	return _unshaded_material(color, emission, 3.1)

static func pickup_material(kind: String) -> StandardMaterial3D:
	var color: Color = Color(0.55, 1.0, 0.42)
	var emission: Color = Color(0.2, 1.0, 0.16)
	if kind == "purge":
		color = Color(0.3, 0.95, 1.0)
		emission = Color(0.0, 0.82, 1.0)
	return _unshaded_material(color, emission, 3.6)

static func pickup_accent_material(kind: String) -> StandardMaterial3D:
	var color: Color = Color(0.92, 1.0, 0.72)
	var emission: Color = Color(0.74, 1.0, 0.28)
	if kind == "purge":
		color = Color(0.72, 1.0, 1.0)
		emission = Color(0.15, 1.0, 1.0)
	return _unshaded_material(color, emission, 4.2)

static func bullet_material() -> StandardMaterial3D:
	return _unshaded_material(Color(0.4, 1.0, 1.0), Color(0.0, 0.95, 1.0), 3.2)

static func enemy_bolt_material() -> StandardMaterial3D:
	return _unshaded_material(Color(1.0, 0.86, 0.20), Color(1.0, 0.7, 0.05), 3.4)

static func burst_material() -> StandardMaterial3D:
	return _unshaded_material(Color(0.15, 1.0, 1.0), Color(0.0, 0.95, 1.0), 3.8)

static func _add_box_part(
	parent: Node3D,
	size: Vector3,
	position: Vector3,
	rotation: Vector3,
	material: StandardMaterial3D
) -> MeshInstance3D:
	var part: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.position = position
	part.rotation = rotation
	part.material_override = material
	parent.add_child(part)
	return part

static func _add_prism_part(
	parent: Node3D,
	size: Vector3,
	position: Vector3,
	rotation: Vector3,
	material: StandardMaterial3D
) -> MeshInstance3D:
	var part: MeshInstance3D = MeshInstance3D.new()
	var mesh: PrismMesh = PrismMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.position = position
	part.rotation = rotation
	part.material_override = material
	parent.add_child(part)
	return part

static func _add_sphere_part(
	parent: Node3D,
	radius: float,
	position: Vector3,
	material: StandardMaterial3D
) -> MeshInstance3D:
	var part: MeshInstance3D = MeshInstance3D.new()
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	part.mesh = mesh
	part.position = position
	part.material_override = material
	parent.add_child(part)
	return part

static func _unshaded_material(color: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material
